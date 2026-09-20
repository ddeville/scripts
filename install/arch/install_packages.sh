#!/bin/bash

set -eu -o pipefail

script_dir=$(cd -- "$(dirname -- "$(realpath -- "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)
pkglist_dir=$(realpath "$script_dir/../../config/linux/.config/pkglist")

# Upgrade the system together with installing the base packages.
readarray -t base_packages < <(grep -Ev "^#|^$" "$pkglist_dir/base_packages.txt")
sudo pacman -Syu --needed -- "${base_packages[@]}"

# Paru is installed by install_as_user.sh before managing AUR packages.
readarray -t aur_packages < <(grep -Ev "^#|^$" "$pkglist_dir/aur_packages.txt")
/usr/bin/paru -Su --needed -- "${aur_packages[@]}"
