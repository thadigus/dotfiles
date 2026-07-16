#!/usr/bin/env bash
set -e
export NIX_CONFIG="experimental-features = nix-command flakes"
git clone https://git.turnerservices.cloud/thadigus/dotfiles.git
cd dotfiles/nixos
select h in $(ls hosts); do break; done </dev/tty
nixos-generate-config --no-filesystems --show-hardware-config >"hosts/$h/hardware-configuration.nix"
git add -A
read -rsp 'LUKS passphrase: ' p </dev/tty; echo; printf %s "$p" >/tmp/disko-password
nix run github:nix-community/disko/latest -- --mode destroy,format,mount --flake ".#$h" --yes-wipe-all-disks
nixos-install --flake ".#$h"
nixos-enter --root /mnt -c 'passwd thadigus'
