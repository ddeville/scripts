#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

PYTHON_VERSION=3.11.8
GOLANG_VERSION=1.22.2
RUST_VERSION=1.76.0
NODE_VERSION=setup_20.x

cd "$HOME"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"

# Latest packages
sudo add-apt-repository universe -y
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-add-repository ppa:fish-shell/release-3 -y

# Current LTS nodejs
curl -sL https://deb.nodesource.com/${NODE_VERSION} | sudo -E bash -

sudo apt-get update

sudo apt-get -y install black \
  build-essential \
  clang-format \
  cmake \
  curl \
  fish \
  gcc \
  gdb \
  gh \
  git \
  htop \
  isort \
  jq \
  libbz2-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  ninja-build \
  nodejs \
  stow \
  tk-dev \
  tmux \
  vim \
  wget \
  xz-utils \
  zlib1g-dev

# Python
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
[ -d "$PYENV_ROOT" ] || curl -L https://pyenv.run | bash
"$PYENV_ROOT/bin/pyenv" update
"$PYENV_ROOT/bin/pyenv" install "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" global "$PYTHON_VERSION"

# Golang
curl -L https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz -o go.tar.gz
sudo rm -rf /opt/go
sudo tar -C /opt -xzf go.tar.gz
rm go.tar.gz

# Rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=${RUST_VERSION} -y --no-modify-path
"$XDG_DATA_HOME/cargo/bin/rustup" default stable
"$XDG_DATA_HOME/cargo/bin/rustup" component add rust-src rustfmt clippy

# Latest nvim
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz -o nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
sudo mv /opt/nvim-linux64 /opt/nvim
rm nvim-linux64.tar.gz

# Latest bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o bazelisk
chmod +x bazelisk
sudo mv bazelisk /usr/local/bin/bazel

# Latest fzf
FZF_VERSION="$(curl -L https://api.github.com/repos/junegunn/fzf/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/junegunn/fzf/releases/download/v"${FZF_VERSION}"/fzf-"${FZF_VERSION}"-linux_amd64.tar.gz -o fzf.tar.gz
tar -xzf fzf.tar.gz
rm fzf.tar.gz
sudo mv fzf /usr/local/bin/fzf

# Latest ripgrep
RIPGREP_VERSION="$(curl -L https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/BurntSushi/ripgrep/releases/download/"${RIPGREP_VERSION}"/ripgrep_"${RIPGREP_VERSION}"-1_amd64.deb -o ripgrep.deb
sudo dpkg -i ripgrep.deb
rm ripgrep.deb

# Latest fd
FD_VERSION="$(curl -L https://api.github.com/repos/sharkdp/fd/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/sharkdp/fd/releases/download/"${FD_VERSION}"/fd_"${FD_VERSION:1}"_amd64.deb -o fd.deb
sudo dpkg -i fd.deb
rm fd.deb

# Install a few programs
export PATH="/opt/nvim/bin:/opt/go/bin:$XDG_DATA_HOME/cargo/bin:$PATH"

go install golang.org/x/tools/gopls@latest
go install github.com/bazelbuild/buildtools/buildifier@latest
go install github.com/bufbuild/buf/cmd/buf@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest

cargo install eza
cargo install stylua

# Change shell to fish
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
