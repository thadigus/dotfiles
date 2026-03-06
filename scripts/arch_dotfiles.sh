#!/bin/bash
set -euo pipefail

cd "$HOME/dotfiles"
stow --adopt hypridle hyprland hyprlock hyprpaper kitty fastfetch zsh
git restore .
