#!/bin/sh
mkdir -p ~/Pictures/Screenshots
grim -g "$(slurp -d)" - | satty --filename - --copy-command "wl-copy" --output-filename "~/Pictures/Screenshots/screenshot-%+.png"
