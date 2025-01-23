#!/bin/bash

# Install packages from packages.list
while read -r package
do
  # Instlal list of packages with Yay
  yay -S --needed "$package"
done < packages.list

# Install OhMyZsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
