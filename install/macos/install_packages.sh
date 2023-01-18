#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
  brew_path=/opt/homebrew/bin
else
  brew_path=/usr/local/bin
fi

if [ ! -x $brew_path/brew ]; then
  echo "Install Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

readarray -t packages <"$script_dir"/brew_packages.txt
packages=("${packages[@]//#*/}")

$brew_path/brew tap homebrew/cask-fonts
$brew_path/brew tap homebrew/cask-versions
$brew_path/brew update
$brew_path/brew install ${packages[@]}
