#!/bin/bash

# Set the directory for the Git repo
export DEV=$HOME/Development
export YAY=$DEV/yay-git
export DOT=$DEV/dotfiles

# Install required packages (for Arch)
sudo pacman -S --needed base-devel git bash
# Install Yay AUR Helper
mkdir -p $DOT
git clone https://aur.archlinux.org/yay-git.git $YAY 
cd $YAY
makepkg -si
# Clone Dotfiles repo
mkdir -p $DOT
git clone git@gitlab.com:thadigus/dotfiles.git $DOT
cd $DOT
# Use script to install OS packages with Yay
./install_packages.sh
# Implement Dotfiles with GNU Stow using Script
./update_dotfiles.sh

