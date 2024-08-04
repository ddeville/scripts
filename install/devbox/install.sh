#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

cd "$HOME"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

sudo apt-get -y install gpg

sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt-get update

sudo apt-get -y install black \
  clang-format \
  cmake \
  curl \
  fd-find \
  fish \
  fzf \
  eza \
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

curl -L0 https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
tar xzvf nvim-linux64.tar.gz && rm nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo mv nvim-linux64 /opt/nvim
sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim

if [ "$SHELL" != "/usr/bin/fish" ]; then
  sudo chsh "$USER" --shell /usr/bin/fish
fi

# Run stow to put all the configs and bins in the right place (making sure to first delete a couple of
# configs that might have been created and that would prevent stow from completing successfully)
rm -f "$HOME/.bashrc" "$HOME/.profile" "$HOME/.config/fish/config.fish" "$HOME/.config/htop/htoprc"
"$HOME/scripts/bin/common/.local/bin/stow-config"

# Install shell plugins
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins"
