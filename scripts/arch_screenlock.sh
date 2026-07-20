#!/usr/bin/env bash
set -euo pipefail

IMG="$HOME/.config/swaylock/screenlock.png"
DIR="$HOME/.config/swaylock/"

mkdir -p "$DIR"

# take screenshot
grim - | magick convert - -scale 10% -scale 1000% -blur 0x8 "$IMG"

# lock screen
swaylock -i "$IMG"
