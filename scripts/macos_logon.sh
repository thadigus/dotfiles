#!/bin/bash

cd $HOME/dotfiles
git pull

brew update
brew upgrade

cd $HOME/dotfiles/scripts
brew bundle

