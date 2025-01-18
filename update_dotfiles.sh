#!/bin/bash

# Required packages: zsh tmux kitty oh-my-zsh hyprland
# Use GNU Stow to propegate the dotfiles
export DOT=$HOME/Development/dotfiles
cd $DOT
stow --no-folding --dir=$PWD --target=$HOME hypr
stow --no-folding --dir=$PWD --target=$HOME images  
stow --no-folding --dir=$PWD --target=$HOME kitty  
stow --no-folding --dir=$PWD --target=$HOME neofetch  
stow --no-folding --dir=$PWD --target=$HOME zsh
