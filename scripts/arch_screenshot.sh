#!/usr/bin/env bash
set -euo pipefail

IMG="$HOME/.swaylock/screenlock.png"
DIR="$HOME/.swaylock"

mkdir -p "$DIR"

# take screenshot
grim - | convert - -scale 10% -scale 1000% -blur 0x8 "$IMG"

# lock screen
swaylock -i "$IMG"
