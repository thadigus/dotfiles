#!/bin/bash

# Required packages: zsh tmux kitty oh-my-zsh hyprland
# Create Developments Folder and Clone Down Main
mkdir -p ~/Development/
cd ~/Development 
git clone git@gitlab.com:thadigus/dotfiles.git
# Copy Desktop Image Assets
cp -r ~/Development/dotfiles/images/* ~/.config/
# Hyprland Config
ln -fs ~/Development/dotfiles/hypr ~/.config/
# Fastfetch (Neofetch Alternative) Config
ln -fs ~/Development/dotfiles/neofetch/neofetch.jsonc ~/.config/neofetch.jsonc
# Kitty Terminal Emulator Config
ln -fs ~/Development/dotfiles/kitty ~/.config/
# Zsh Shell Configuration (With Oh My Zsh)
ln -fs ~/Development/dotfiles/shell/.zshrc ~/.zshrc
