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

homebrew_dir="$script_dir/../../config/macos/.config/homebrew"
brewfile="$(mktemp -d)/Brewfile"
trap 'rm -rf "$(dirname "$brewfile")"' EXIT
cat "$homebrew_dir/Brewfile.common" >"$brewfile"
if [[ -f "$homebrew_dir/Brewfile.openai" ]]; then
  cat "$homebrew_dir/Brewfile.openai" >>"$brewfile"
elif [[ -f "$homebrew_dir/Brewfile.home" ]]; then
  cat "$homebrew_dir/Brewfile.home" >>"$brewfile"
fi

$brew update
$brew bundle install --file="$brewfile" --no-lock --upgrade --cleanup
