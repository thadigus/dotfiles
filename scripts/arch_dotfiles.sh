#!/bin/bash
set -euo pipefail

cd "$HOME/dotfiles"
stow --adopt kitty fastfetch zsh
git restore .
