#!/bin/bash

while read -r package
do
  # Implmenet the symlinks with GNU Stow 
  stow --no-folding --dir=$PWD --target=$HOME "$package"
done < packages.list

