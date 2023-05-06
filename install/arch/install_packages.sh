#!/bin/bash

set -eu

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Install all the base packages
readarray -t base_packages < <(grep -Ev "^#|^\$" "$script_dir/base_packages.txt")
sudo pacman -Syy
sudo pacman -S --needed "${base_packages[@]}"

# Install AUR packages with Paru
readarray -t aur_packages < <(grep -Ev "^#|^\$" "$script_dir/aur_packages.txt")
/usr/bin/paru -Syy
/usr/bin/paru -S --needed "${aur_packages[@]}"
