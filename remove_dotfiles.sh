#!/bin/bash

while read -r package
do
  # Implmenet the symlinks with GNU Stow 
  stow -d --dir=$PWD --target=$HOME "$package"
done < packages.list

