#!/usr/bin/env bash
set -euo pipefail

BGR="$HOME/.config/desktopwallpaper.png"
IMG="$HOME/.config/swaylock/screenlock.png"
DIR="$HOME/.config/swaylock/"

mkdir -p "$DIR"

if [ ! -f "$IMG" ]; then
  magick $BGR -scale 10% -scale 1000% -blur 0x8 "$IMG"
fi

# lock screen
swaylock -i "$IMG"
