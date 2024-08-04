#!/bin/bash

set -eu

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

cd "$HOME"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

sudo apt-get install black \
  clang-format \
  cmake \
  curl \
  fd-find \
  fish \
  fzf \
  gcc \
  gdb \
  gh \
  git \
  htop \
  isort \
  jq \
  neovim \
  ninja-build \
  nodejs \
  npm \
  ripgrep \
  stow \
  tmux \
  vim \
  wget

if [ "$SHELL" != "/usr/bin/fish" ]; then
  chsh --shell /usr/bin/fish
fi

# Run stow to put all the configs and bins in the right place (making sure to first delete a couple of
# configs that might have been created and that would prevent stow from completing successfully)
rm -f "$HOME/.bashrc" "$HOME/.profile"
"$HOME/scripts/bin/common/.local/bin/stow-config"

# Install shell plugins and terminfos
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins"
"$HOME/scripts/bin/macos/.local/bin/update-terminfo"
