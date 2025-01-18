#!/bin/bash

# Required packages: zsh tmux kitty oh-my-zsh hyprland
# Use GNU Stow to propegate the dotfiles
export DOT=$HOME/Development/dotfiles
cd $DOT
stow -d --dir=$PWD --target=$HOME hypr
stow -d --dir=$PWD --target=$HOME images  
stow -d --dir=$PWD --target=$HOME kitty  
stow -d --dir=$PWD --target=$HOME neofetch  
stow -d --dir=$PWD --target=$HOME zsh
