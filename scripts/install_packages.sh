#!/bin/bash

# Install packages from packages.list
yay -S --needed $(cat packages.list)

# Install OhMyZsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
