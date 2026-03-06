#!/usr/bin/env bash
set -euo pipefail

# Arch Linux bare-metal bootstrap for laptop/desktop hosts.
# WARNING: This script is destructive and will wipe target disks.

VG_NAME="vgroot"
CRYPT_NAME="cryptroot"
CRYPT_BOOT_NAME="cryptboot"
MOUNT_ROOT="/mnt"
INSTALL_USERNAME=""
INSTALL_HOSTNAME=""
BOOT_LUKS_PASSPHRASE=""
ROOT_LUKS_PASSPHRASE=""
USER_PASSWORD=""

BASE_PKGS=(
  base linux linux-firmware
  grub efibootmgr
  networkmanager sudo ansible git
  lvm2 cryptsetup mdadm
  dosfstools e2fsprogs util-linux
  sbctl
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

cleanup_previous_attempt() {
  info "Cleaning up any previous partial install state"
  swapoff -a 2>/dev/null || true
  umount -R "$MOUNT_ROOT" 2>/dev/null || true

  if vgdisplay "$VG_NAME" >/dev/null 2>&1; then
    vgchange -an "$VG_NAME" 2>/dev/null || true
  fi

  if cryptsetup status "$CRYPT_BOOT_NAME" >/dev/null 2>&1; then
    cryptsetup close "$CRYPT_BOOT_NAME" 2>/dev/null || true
  fi

  if cryptsetup status "$CRYPT_NAME" >/dev/null 2>&1; then
    cryptsetup close "$CRYPT_NAME" 2>/dev/null || true
  fi

  mdadm --stop /dev/md0 2>/dev/null || true
  mdadm --stop /dev/md1 2>/dev/null || true
  mdadm --stop /dev/md2 2>/dev/null || true
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

prompt_secret_twice() {
  local prompt="$1"
  local first second
  [[ -r /dev/tty ]] || err "No interactive TTY available for prompts."
  while true; do
    printf '%s' "$prompt" >/dev/tty
    IFS= read -r -s first </dev/tty || err "Failed to read secret input."
    first="$(printf '%s' "$first" | tr -d '\r')"
    printf '\n' >/dev/tty
    printf 'Confirm: ' >/dev/tty
    IFS= read -r -s second </dev/tty || err "Failed to read secret input."
    second="$(printf '%s' "$second" | tr -d '\r')"
    printf '\n' >/dev/tty
    [[ -n "$first" ]] || { printf 'Value cannot be empty.\n' >/dev/tty; continue; }
    [[ "$first" == "$second" ]] || { printf 'Values do not match.\n' >/dev/tty; continue; }
    printf '%s' "$first"
    return
  done
}

collect_initial_inputs() {
  INSTALL_USERNAME="$(prompt_input "Username to create: ")"
  [[ "$INSTALL_USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || err "Invalid username format."

  INSTALL_HOSTNAME="$(prompt_input "Hostname: ")"
  [[ "$INSTALL_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || err "Invalid hostname format."

  BOOT_LUKS_PASSPHRASE="$(prompt_secret_twice "Boot LUKS passphrase: ")"
  ROOT_LUKS_PASSPHRASE="$(prompt_secret_twice "Root LUKS passphrase: ")"
  USER_PASSWORD="$(prompt_secret_twice "Password for $INSTALL_USERNAME: ")"
}

list_nvme_disks() {
  lsblk -d -b -n -o NAME,SIZE,TYPE | awk '$3=="disk" && $1 ~ /^nvme/ {printf "/dev/%s %s\n", $1, $2}' | sort -V
}

detect_install_layout() {
  local -a info
  local i j disk_i size_i disk_j size_j
  mapfile -t info < <(list_nvme_disks)
  [[ "${#info[@]}" -gt 0 ]] || err "No NVMe disks detected."

  if [[ "${#info[@]}" -eq 1 ]]; then
    printf 'single %s\n' "$(awk '{print $1}' <<<"${info[0]}")"
    return
  fi

  for (( i=0; i<${#info[@]}; i++ )); do
    disk_i="$(awk '{print $1}' <<<"${info[i]}")"
    size_i="$(awk '{print $2}' <<<"${info[i]}")"
    for (( j=i+1; j<${#info[@]}; j++ )); do
      disk_j="$(awk '{print $1}' <<<"${info[j]}")"
      size_j="$(awk '{print $2}' <<<"${info[j]}")"
      if [[ "$size_i" == "$size_j" ]]; then
        printf 'raid %s %s\n' "$disk_i" "$disk_j"
        return
      fi
    done
  done

  printf 'single %s\n' "$(awk '{print $1}' <<<"${info[0]}")"
}

partition_target() {
  local target="$1"
  info "Partitioning $target"

  sgdisk --zap-all "$target"
  sgdisk -o "$target"
  sgdisk -n 1:1MiB:+550MiB -t 1:EF00 -c 1:EFI "$target"
  sgdisk -n 2:0:+2GiB -t 2:8309 -c 2:CRYPTBOOT "$target"
  sgdisk -n 3:0:0 -t 3:8309 -c 3:CRYPTROOT "$target"
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
    sgdisk -n 2:0:+2GiB -t 2:FD00 -c 2:RAIDBOOT "$d"
    sgdisk -n 3:0:0 -t 3:FD00 -c 3:RAIDROOT "$d"
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
  local boot_crypt_part="$2"
  local root_crypt_part="$3"
  local boot_key_file root_key_file

  boot_key_file="$(mktemp)"
  root_key_file="$(mktemp)"
  chmod 600 "$boot_key_file" "$root_key_file"
  trap 'rm -f "$boot_key_file" "$root_key_file"' RETURN
  printf '%s' "$BOOT_LUKS_PASSPHRASE" >"$boot_key_file"
  printf '%s' "$ROOT_LUKS_PASSPHRASE" >"$root_key_file"

  info "Formatting EFI partition: $efi_part"
  mkfs.fat -F32 "$efi_part"

  info "Creating /boot LUKS container (PBKDF2 for GRUB): $boot_crypt_part"
  cryptsetup luksFormat --batch-mode --pbkdf pbkdf2 --key-file "$boot_key_file" "$boot_crypt_part"
  cryptsetup open "$boot_crypt_part" "$CRYPT_BOOT_NAME" --key-file "$boot_key_file"
  mkfs.ext4 "/dev/mapper/$CRYPT_BOOT_NAME"

  info "Creating root LUKS container (default stronger settings): $root_crypt_part"
  cryptsetup luksFormat --batch-mode --key-file "$root_key_file" "$root_crypt_part"
  cryptsetup open "$root_crypt_part" "$CRYPT_NAME" --key-file "$root_key_file"

  info "Creating LVM on /dev/mapper/$CRYPT_NAME"
  pvcreate "/dev/mapper/$CRYPT_NAME"
  vgcreate "$VG_NAME" "/dev/mapper/$CRYPT_NAME"

  local ram_kb swap_gb
  ram_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  swap_gb="$(( (ram_kb + 1024*1024 - 1) / (1024*1024) + 1 ))"

  info "Creating logical volumes (swap=${swap_gb}G)"
  lvcreate -L "${swap_gb}G" -n swap "$VG_NAME"
  lvcreate -l 23%FREE -n root "$VG_NAME"
  lvcreate -l 12%FREE -n var "$VG_NAME"
  lvcreate -l 8%FREE -n var_log "$VG_NAME"
  lvcreate -l 4%FREE -n var_log_audit "$VG_NAME"
  lvcreate -l 10%FREE -n opt "$VG_NAME"
  lvcreate -l 100%FREE -n home "$VG_NAME"

  info "Formatting filesystems"
  mkfs.ext4 "/dev/$VG_NAME/root"
  mkfs.ext4 "/dev/$VG_NAME/home"
  mkfs.ext4 "/dev/$VG_NAME/var"
  mkfs.ext4 "/dev/$VG_NAME/var_log"
  mkfs.ext4 "/dev/$VG_NAME/var_log_audit"
  mkfs.ext4 "/dev/$VG_NAME/opt"
  mkswap "/dev/$VG_NAME/swap"

  info "Mounting target filesystems"
  mount "/dev/$VG_NAME/root" "$MOUNT_ROOT"
  mount --mkdir "/dev/mapper/$CRYPT_BOOT_NAME" "$MOUNT_ROOT/boot"
  mount --mkdir "$efi_part" "$MOUNT_ROOT/boot/efi"
  mount --mkdir "/dev/$VG_NAME/home" "$MOUNT_ROOT/home"
  mount --mkdir "/dev/$VG_NAME/var" "$MOUNT_ROOT/var"
  mount --mkdir "/dev/$VG_NAME/var_log" "$MOUNT_ROOT/var/log"
  mount --mkdir "/dev/$VG_NAME/var_log_audit" "$MOUNT_ROOT/var/log/audit"
  mount --mkdir "/dev/$VG_NAME/opt" "$MOUNT_ROOT/opt"
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

detect_gpu_vendor() {
  local lspci_out
  lspci_out="$(lspci | tr '[:upper:]' '[:lower:]')"
  if grep -q 'nvidia' <<<"$lspci_out"; then
    printf 'nvidia'
    return
  fi
  if grep -E -q 'amd/ati|advanced micro devices|radeon' <<<"$lspci_out"; then
    printf 'amd'
    return
  fi
  printf 'generic'
}

configure_system() {
  local root_luks_part="$1"
  local boot_luks_part="$2"
  local install_mode="$3"
  local user_password_hash

  local microcode gpu_vendor
  local -a requested_pkgs
  microcode="$(detect_cpu_microcode)"
  gpu_vendor="$(detect_gpu_vendor)"
  requested_pkgs=("${BASE_PKGS[@]}")
  if [[ -n "$microcode" ]]; then
    requested_pkgs+=("$microcode")
  fi

  info "Installing base system via pacstrap"
  pacstrap -K "$MOUNT_ROOT" "${requested_pkgs[@]}"

  genfstab -U "$MOUNT_ROOT" >> "$MOUNT_ROOT/etc/fstab"

  if [[ "$install_mode" == "raid" ]] && [[ -e /dev/md0 ]]; then
    mdadm --detail --scan > "$MOUNT_ROOT/etc/mdadm.conf"
  fi

  local root_luks_uuid boot_luks_uuid
  root_luks_uuid="$(blkid -s UUID -o value "$root_luks_part")"
  boot_luks_uuid="$(blkid -s UUID -o value "$boot_luks_part")"
  user_password_hash="$(printf '%s' "$USER_PASSWORD" | openssl passwd -6 -stdin)"

  cat > "$MOUNT_ROOT/root/postinstall.sh" <<CHROOT
#!/usr/bin/env bash
set -euo pipefail

ln -sf /usr/share/zoneinfo/America/Indiana/Indianapolis /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo '$INSTALL_HOSTNAME' > /etc/hostname
cat > /etc/hosts <<'HOSTS'
127.0.0.1 localhost
::1 localhost
127.0.1.1 $INSTALL_HOSTNAME.localdomain $INSTALL_HOSTNAME
HOSTS

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block mdadm_udev encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

cat > /etc/crypttab <<'CRYPTTAB'
$CRYPT_BOOT_NAME UUID=$boot_luks_uuid none luks
CRYPTTAB

sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers

useradd -m -G wheel -s /bin/bash -p '$user_password_hash' $INSTALL_USERNAME

# Keep root account locked; use sudo from wheel users.
passwd -l root || true

systemctl enable NetworkManager
systemctl enable mdmonitor || true

if [[ "$gpu_vendor" == "amd" ]]; then
  pacman -S --noconfirm --needed mesa xf86-video-amdgpu vulkan-radeon || true
elif [[ "$gpu_vendor" == "nvidia" ]]; then
  # Arch official path (current): nvidia-open stack.
  if pacman -Si nvidia-open >/dev/null 2>&1; then
    pacman -S --noconfirm --needed nvidia-open nvidia-utils nvidia-settings || true
  elif pacman -Si nvidia >/dev/null 2>&1; then
    pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings || true
  else
    # Legacy branches are AUR-only; install via yay-bin fallback.
    pacman -S --noconfirm --needed base-devel git dkms linux-headers || true
    echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-wheel-nopasswd
    chmod 440 /etc/sudoers.d/99-wheel-nopasswd
    if ! command -v yay >/dev/null 2>&1; then
      su - $INSTALL_USERNAME -c 'rm -rf ~/yay-bin && git clone https://aur.archlinux.org/yay-bin.git ~/yay-bin && cd ~/yay-bin && makepkg -si --noconfirm --needed' </dev/tty >/dev/tty || true
    fi
    su - $INSTALL_USERNAME -c 'yay -S --noconfirm --needed nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings || yay -S --noconfirm --needed nvidia-470xx-dkms nvidia-470xx-utils nvidia-470xx-settings || yay -S --noconfirm --needed nvidia-390xx-dkms nvidia-390xx-utils nvidia-390xx-settings' </dev/tty >/dev/tty || true
    rm -f /etc/sudoers.d/99-wheel-nopasswd
  fi
else
  pacman -S --noconfirm --needed mesa || true
fi

echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
sed -i 's|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="cryptdevice=UUID=$root_luks_uuid:$CRYPT_NAME root=/dev/$VG_NAME/root resume=/dev/$VG_NAME/swap"|' /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

# Secure Boot setup with sbctl (best-effort).
mountpoint -q /sys/firmware/efi/efivars || mount -t efivarfs efivarfs /sys/firmware/efi/efivars || true
sbctl create-keys || true
sbctl enroll-keys </dev/tty >/dev/tty || true
if [[ -d /var/lib/sbctl/keys ]]; then
  sbctl sign-all || true
fi
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
  need_cmd openssl

  if [[ "${EUID}" -ne 0 ]]; then
    err "Run as root."
  fi

  info "Arch install bootstrap."
  cleanup_previous_attempt

  collect_initial_inputs

  local install_mode disk_a disk_b target_disk efi_part boot_luks_part root_luks_part
  read -r install_mode disk_a disk_b < <(detect_install_layout)
  info "Detected install mode: $install_mode"

  if [[ "$install_mode" == "raid" ]]; then
    [[ -n "${disk_a:-}" && -n "${disk_b:-}" ]] || err "RAID mode selected but disk pair was not resolved."
    info "Using RAID1 across: $disk_a and $disk_b"

    partition_raid_members "$disk_a" "$disk_b"
    mdadm --stop /dev/md0 2>/dev/null || true
    mdadm --stop /dev/md1 2>/dev/null || true
    mdadm --stop /dev/md2 2>/dev/null || true
    mdadm --zero-superblock \
      "$(part_path "$disk_a" 1)" "$(part_path "$disk_b" 1)" \
      "$(part_path "$disk_a" 2)" "$(part_path "$disk_b" 2)" \
      "$(part_path "$disk_a" 3)" "$(part_path "$disk_b" 3)" || true

    mdadm --create /dev/md0 --level=1 --raid-devices=2 --metadata=1.0 \
      "$(part_path "$disk_a" 1)" "$(part_path "$disk_b" 1)"
    mdadm --create /dev/md1 --level=1 --raid-devices=2 --metadata=1.2 \
      "$(part_path "$disk_a" 2)" "$(part_path "$disk_b" 2)"
    mdadm --create /dev/md2 --level=1 --raid-devices=2 --metadata=1.2 \
      "$(part_path "$disk_a" 3)" "$(part_path "$disk_b" 3)"

    efi_part="/dev/md0"
    boot_luks_part="/dev/md1"
    root_luks_part="/dev/md2"
  else
    target_disk="$disk_a"
    [[ -n "${target_disk:-}" ]] || err "Single-disk mode selected but disk was not resolved."
    info "Using single NVMe disk: $target_disk"
    partition_target "$target_disk"
    efi_part="$(part_path "$target_disk" 1)"
    boot_luks_part="$(part_path "$target_disk" 2)"
    root_luks_part="$(part_path "$target_disk" 3)"
  fi

  setup_luks_lvm "$efi_part" "$boot_luks_part" "$root_luks_part"
  configure_system "$root_luks_part" "$boot_luks_part" "$install_mode"

  info "Install complete. Syncing disks, unmounting, and rebooting."
  sync
  swapoff -a || true
  umount -R "$MOUNT_ROOT" || true
  cryptsetup close "$CRYPT_BOOT_NAME" || true
  cryptsetup close "$CRYPT_NAME" || true
  sleep 3
  reboot
}

main "$@"
