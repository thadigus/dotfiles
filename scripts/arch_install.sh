#!/usr/bin/env bash
set -euo pipefail

# Arch Linux bare-metal bootstrap for laptop/desktop hosts.
# WARNING: This script is destructive and will wipe target disks.

USERNAME="thadigus"
VG_NAME="vgroot"
CRYPT_NAME="cryptroot"
MOUNT_ROOT="/mnt"

BASE_PKGS=(
  base linux linux-firmware
  grub efibootmgr
  networkmanager sudo vim git
  lvm2 cryptsetup mdadm
  dosfstools e2fsprogs util-linux
)

err() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '\n==> %s\n' "$*"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Missing required command: $1"
}

prepare_tty() {
  # Some environments send CR without LF when piping script into bash.
  stty -F /dev/tty sane icrnl echo icanon 2>/dev/null \
    || stty sane icrnl echo icanon </dev/tty >/dev/tty 2>/dev/null \
    || true
}

prompt_input() {
  local prompt="$1"
  local value
  [[ -r /dev/tty ]] || err "No interactive TTY available for prompts."
  prepare_tty
  printf '%s' "$prompt" >/dev/tty
  IFS= read -r value </dev/tty || err "Failed to read user input."
  value="$(printf '%s' "$value" | tr -d '\r')"
  printf '%s' "$value"
}

prompt_choice() {
  local prompt="$1"
  local valid="$2"
  local key
  [[ -r /dev/tty ]] || err "No interactive TTY available for prompts."
  prepare_tty
  while true; do
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r -n 1 key </dev/tty || err "Failed to read user input."
    printf '\n' >/dev/tty
    key="$(printf '%s' "$key" | tr -d '\r[:space:]')"
    [[ -n "$key" ]] || continue
    if [[ "$valid" == *"$key"* ]]; then
      printf '%s' "$key"
      return
    fi
    printf 'Invalid selection.\n' >/dev/tty
  done
}

choose_raid_mode() {
  cat >/dev/tty <<'TXT'
Configure RAID1?
Note: RAID enabled uses two matching disks. RAID disabled uses one selected disk.
1) yes (RAID1)
2) no (single disk)
TXT
  choice="$(prompt_choice "Enable RAID [1-2]: " "12")"
  case "$choice" in
    1) printf 'raid' ;;
    2) printf 'single' ;;
    *) err "Invalid RAID selection." ;;
  esac
}

list_disks() {
  lsblk -d -n -o NAME,SIZE,MODEL,TYPE,TRAN | awk '$4=="disk" {printf "/dev/%s | size=%s | model=%s | bus=%s\n", $1,$2,$3,$5}'
}

find_raid_pair() {
  lsblk -d -n -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk" {print $1"|"$2"|"$3}' \
    | sort \
    | awk -F'|' '
      {
        key=$2"|"$3
        count[key]++
        disks[key]=(disks[key] ? disks[key]" "$1 : $1)
      }
      END {
        for (k in count) {
          if (count[k] >= 2) {
            split(disks[k], arr, " ")
            print arr[1], arr[2]
            exit
          }
        }
      }
    '
}

select_single_disk() {
  printf '\n==> Available disks:\n' >/dev/tty
  list_disks >/dev/tty
  disk="$(prompt_input "Enter target disk (example: /dev/nvme0n1): ")"
  [[ -b "$disk" ]] || err "Invalid disk: $disk"
  printf '%s' "$disk"
}

partition_target() {
  local target="$1"
  info "Partitioning $target"

  sgdisk --zap-all "$target"
  sgdisk -o "$target"
  sgdisk -n 1:1MiB:+550MiB -t 1:EF00 -c 1:EFI "$target"
  sgdisk -n 2:0:0 -t 2:8309 -c 2:CRYPTROOT "$target"
  partprobe "$target"

  sleep 2
}

partition_raid_members() {
  local disk_a="$1"
  local disk_b="$2"

  info "Partitioning RAID member disks: $disk_a and $disk_b"
  for d in "$disk_a" "$disk_b"; do
    sgdisk --zap-all "$d"
    sgdisk -o "$d"
    sgdisk -n 1:1MiB:+550MiB -t 1:FD00 -c 1:RAIDEFI "$d"
    sgdisk -n 2:0:0 -t 2:FD00 -c 2:RAIDROOT "$d"
    partprobe "$d"
  done

  sleep 2
}

part_path() {
  local disk="$1"
  local part="$2"
  if [[ "$disk" =~ nvme|mmcblk|md ]]; then
    printf '%sp%s' "$disk" "$part"
  else
    printf '%s%s' "$disk" "$part"
  fi
}

setup_luks_lvm() {
  local efi_part="$1"
  local crypt_part="$2"

  info "Formatting EFI partition: $efi_part"
  mkfs.fat -F32 "$efi_part"

  info "Creating LUKS container: $crypt_part"
  cryptsetup luksFormat "$crypt_part"
  cryptsetup open "$crypt_part" "$CRYPT_NAME"

  info "Creating LVM on /dev/mapper/$CRYPT_NAME"
  pvcreate "/dev/mapper/$CRYPT_NAME"
  vgcreate "$VG_NAME" "/dev/mapper/$CRYPT_NAME"

  local ram_kb swap_gb
  ram_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  swap_gb="$(( (ram_kb + 1024*1024 - 1) / (1024*1024) + 1 ))"

  info "Creating logical volumes (swap=${swap_gb}G)"
  lvcreate -L "${swap_gb}G" -n swap "$VG_NAME"
  lvcreate -l 20%FREE -n root "$VG_NAME"
  lvcreate -l 3%FREE -n boot "$VG_NAME"
  lvcreate -l 12%FREE -n var "$VG_NAME"
  lvcreate -l 8%FREE -n var_log "$VG_NAME"
  lvcreate -l 4%FREE -n var_log_audit "$VG_NAME"
  lvcreate -l 10%FREE -n opt "$VG_NAME"
  lvcreate -l 100%FREE -n home "$VG_NAME"

  info "Formatting filesystems"
  mkfs.ext4 "/dev/$VG_NAME/root"
  mkfs.ext4 "/dev/$VG_NAME/boot"
  mkfs.ext4 "/dev/$VG_NAME/home"
  mkfs.ext4 "/dev/$VG_NAME/var"
  mkfs.ext4 "/dev/$VG_NAME/var_log"
  mkfs.ext4 "/dev/$VG_NAME/var_log_audit"
  mkfs.ext4 "/dev/$VG_NAME/opt"
  mkswap "/dev/$VG_NAME/swap"

  info "Mounting target filesystems"
  mount "/dev/$VG_NAME/root" "$MOUNT_ROOT"
  mkdir -p "$MOUNT_ROOT"/{boot,home,var,opt}
  mkdir -p "$MOUNT_ROOT"/var/log/audit
  mkdir -p "$MOUNT_ROOT"/boot/efi

  mount "/dev/$VG_NAME/boot" "$MOUNT_ROOT/boot"
  mount "$efi_part" "$MOUNT_ROOT/boot/efi"
  mount "/dev/$VG_NAME/home" "$MOUNT_ROOT/home"
  mount "/dev/$VG_NAME/var" "$MOUNT_ROOT/var"
  mount "/dev/$VG_NAME/var_log" "$MOUNT_ROOT/var/log"
  mount "/dev/$VG_NAME/var_log_audit" "$MOUNT_ROOT/var/log/audit"
  mount "/dev/$VG_NAME/opt" "$MOUNT_ROOT/opt"
  swapon "/dev/$VG_NAME/swap"
}

detect_cpu_microcode() {
  local vendor
  vendor="$(awk -F: '/vendor_id/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo)"
  case "$vendor" in
    GenuineIntel) printf 'intel-ucode' ;;
    AuthenticAMD) printf 'amd-ucode' ;;
    *) printf '' ;;
  esac
}

detect_gpu_pkgs() {
  local lspci_out
  lspci_out="$(lspci | tr '[:upper:]' '[:lower:]')"
  if grep -q 'nvidia' <<<"$lspci_out"; then
    printf 'nvidia nvidia-utils nvidia-settings'
    return
  fi
  if grep -E -q 'amd/ati|advanced micro devices|radeon' <<<"$lspci_out"; then
    printf 'mesa xf86-video-amdgpu vulkan-radeon'
    return
  fi
  printf 'mesa'
}

read_extra_packages() {
  local pkg_file="scripts/arch_packages.list"
  if [[ -f "$pkg_file" ]]; then
    grep -Ev '^\s*(#|$)' "$pkg_file" | tr '\n' ' '
    return
  fi
  printf '%s' 'bash-completion base-devel man-db man-pages openssh stow tmux zsh kitty dolphin rofi fastfetch hypridle hyprland hyprlock hyprpaper wayland xorg-xwayland qt5-wayland qt6-wayland xdg-desktop-portal swaync waybar wl-clipboard xdg-desktop-portal-hyprland pipewire wireplumber polkit network-manager-applet grim slurp playerctl brightnessctl proton-vpn-gtk-app'
}

configure_system() {
  local luks_part="$1"
  local install_mode="$2"
  local hostname

  if [[ "$install_mode" == "raid" ]]; then
    hostname="archwhitebox"
  else
    hostname="archlaptop"
  fi

  local microcode gpu_pkgs extra_pkgs
  microcode="$(detect_cpu_microcode)"
  gpu_pkgs="$(detect_gpu_pkgs)"
  extra_pkgs="$(read_extra_packages)"

  info "Installing base system via pacstrap"
  # shellcheck disable=SC2086
  pacstrap -K "$MOUNT_ROOT" ${BASE_PKGS[*]} $microcode $gpu_pkgs $extra_pkgs

  genfstab -U "$MOUNT_ROOT" >> "$MOUNT_ROOT/etc/fstab"

  if [[ "$install_mode" == "raid" ]] && [[ -e /dev/md0 ]]; then
    mdadm --detail --scan > "$MOUNT_ROOT/etc/mdadm.conf"
  fi

  local luks_uuid
  luks_uuid="$(blkid -s UUID -o value "$luks_part")"

  cat > "$MOUNT_ROOT/root/postinstall.sh" <<CHROOT
#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/America/Indiana/Indianapolis /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo '$hostname' > /etc/hostname
cat > /etc/hosts <<'HOSTS'
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
HOSTS

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block mdadm_udev encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers

useradd -m -G wheel -s /bin/bash $USERNAME
echo 'Set password for $USERNAME:'
passwd $USERNAME

echo 'Set root password:'
passwd

systemctl enable NetworkManager
systemctl enable mdmonitor || true

# Install yay and use AUR for Zen + Proton desktop apps.
pacman -S --needed --noconfirm base-devel git
if ! command -v yay >/dev/null 2>&1; then
  su - $USERNAME -c 'rm -rf ~/yay && git clone https://aur.archlinux.org/yay.git ~/yay && cd ~/yay && makepkg -si --noconfirm --needed'
fi
su - $USERNAME -c 'yay -S --noconfirm --needed zen-browser-bin proton-mail-bin proton-pass-bin'

echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
sed -i 's|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="cryptdevice=UUID=$luks_uuid:$CRYPT_NAME root=/dev/$VG_NAME/root resume=/dev/$VG_NAME/swap"|' /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

  chmod +x "$MOUNT_ROOT/root/postinstall.sh"
  arch-chroot "$MOUNT_ROOT" /root/postinstall.sh
  rm -f "$MOUNT_ROOT/root/postinstall.sh"
}

main() {
  need_cmd lsblk
  need_cmd mdadm
  need_cmd sgdisk
  need_cmd cryptsetup
  need_cmd pvcreate
  need_cmd pacstrap
  need_cmd arch-chroot
  need_cmd lspci

  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root."
  fi

  info "Arch install bootstrap."

  local install_mode disk_a disk_b target_disk efi_part luks_part
  install_mode="$(choose_raid_mode)"
  info "Install mode: $install_mode"

  if [[ "$install_mode" == "raid" ]]; then
    info "Locating matching disks for RAID1"
    read -r disk_a disk_b < <(find_raid_pair || true)
    if [[ -z "${disk_a:-}" || -z "${disk_b:-}" ]]; then
      err "Could not auto-find two matching disks for RAID1."
    fi

    disk_a="/dev/$disk_a"
    disk_b="/dev/$disk_b"

    info "Using disks for RAID1: $disk_a and $disk_b"
    raid_confirm="$(prompt_choice "Continue with these disks? [y/N]: " "yYnN")"
    [[ "$raid_confirm" =~ ^[Yy]$ ]] || err "RAID setup canceled."

    partition_raid_members "$disk_a" "$disk_b"
    mdadm --stop /dev/md0 2>/dev/null || true
    mdadm --stop /dev/md1 2>/dev/null || true
    mdadm --zero-superblock \
      "$(part_path "$disk_a" 1)" "$(part_path "$disk_b" 1)" \
      "$(part_path "$disk_a" 2)" "$(part_path "$disk_b" 2)" || true

    mdadm --create /dev/md1 --level=1 --raid-devices=2 --metadata=1.0 \
      "$(part_path "$disk_a" 1)" "$(part_path "$disk_b" 1)"
    mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.2 "$(part_path "$disk_a" 2)" "$(part_path "$disk_b" 2)"

    efi_part="/dev/md1"
    luks_part="/dev/md0"
  else
    target_disk="$(select_single_disk)"
    partition_target "$target_disk"
    efi_part="$(part_path "$target_disk" 1)"
    luks_part="$(part_path "$target_disk" 2)"
  fi

  setup_luks_lvm "$efi_part" "$luks_part"
  configure_system "$luks_part" "$install_mode"

  info "Install complete. Syncing disks, unmounting, and rebooting."
  sync
  swapoff -a || true
  umount -R "$MOUNT_ROOT" || true
  cryptsetup close "$CRYPT_NAME" || true
  sleep 3
  reboot
}

main "$@"
