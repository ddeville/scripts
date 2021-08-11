#!/bin/sh

# /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
    brew_path=/opt/homebrew/bin/brew
else
    brew_path=/usr/local/bin/brew
fi

$brew_path install \
    bat exa fish htop jq neovim ripgrep stow tmux fd cmake ninka \
    pyenv golang node robotsandpencils/made/xcodes
