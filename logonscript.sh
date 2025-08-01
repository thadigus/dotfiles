#!/bin/bash

cd $HOME/dotfiles
git pull

brew bundle

stow --adopt kitty fastfetch zsh
git restore *
