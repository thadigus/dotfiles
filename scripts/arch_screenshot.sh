#!/bin/sh
mkdir -p ~/Pictures/Screenshots
grim -g "$(slurp -d)" - | satty --filename - --output-filename "~/Pictures/Screenshots/screenshot-%+.png"
