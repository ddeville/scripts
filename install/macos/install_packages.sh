#!/bin/bash

set -eu

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
  brew=/opt/homebrew/bin/brew
else
  brew=/usr/local/bin/brew
fi

if [ ! -x $brew ]; then
  echo "Install Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

$brew tap homebrew/cask-fonts
$brew tap homebrew/cask-versions
$brew update

# NOTE: `readarray` is available in bash 4.0+ but macos uses an old 3.2 version of bash...
packages=()
while IFS= read -r line; do
  [[ ! $line =~ ^#|^$ ]] && packages+=("$line")
done <"$script_dir/brew_packages.txt"

$brew install --no-quarantine "${packages[@]}"
$brew upgrade
