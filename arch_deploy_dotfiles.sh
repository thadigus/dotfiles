#!/bin/bash

# Required packages: zsh tmux kitty oh-my-zsh hyprland
# Install required packages (for Arch)
yay -S git zsh tmux kitty oh-my-zsh hyprland stow
# Make the dotfiles repo in the Development folder
mkdir -p ~/Development/dotfiles
# Clone the repo down
git clone git@gitlab.com:thadigus/dotfiles.git ~/Development/dotfiles
# Use GNU Stow to propegate the dotfiles
export DOT=$HOME/Development/dotfiles
cd $DOT
update_dotfiles.sh
