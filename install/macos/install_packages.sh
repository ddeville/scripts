#!/bin/bash

set -eu -o pipefail

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

$brew update
$brew bundle install --file="$script_dir/../../config/macos/.config/homebrew/Brewfile" --no-lock --upgrade --cleanup
