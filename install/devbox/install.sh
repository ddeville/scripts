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

mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"

##### Base packages #####

# Latest packages
sudo add-apt-repository universe -y
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-add-repository ppa:fish-shell/release-3 -y

# Current LTS nodejs
curl -sL https://deb.nodesource.com/${NODE_VERSION} | sudo -E bash -

sudo apt-get update

sudo apt-get -y install \
  bison \
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
  jq \
  libbz2-dev \
  libevent \
  libevent-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  ncurses \
  ncurses-dev \
  ninja-build \
  nodejs \
  pkg-config \
  stow \
  tk-dev \
  tmux \
  unzip \
  vim \
  wget \
  xz-utils \
  zlib1g-dev

##### Toolchains #####

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

# Python
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
[ -d "$PYENV_ROOT" ] || curl -L https://pyenv.run | bash
"$PYENV_ROOT/bin/pyenv" update
"$PYENV_ROOT/bin/pyenv" install --skip-existing "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" global "$PYTHON_VERSION"

##### Programs #####

INSTALL_TMPDIR="$(mktemp -d)"

pushd "$INSTALL_TMPDIR"

# neovim
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz -o nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz && rm nvim-linux64.tar.gz
sudo mv /opt/nvim-linux64 /opt/nvim

# bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o bazelisk
chmod +x bazelisk
sudo mv bazelisk /usr/local/bin/bazel

# buildifier
curl -L https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-amd64.zip -o buildifier
chmod +x buildifier
sudo mv buildifier /usr/local/bin/buildifier

# eza
curl -L https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -o eza.tar.gz
tar -xzf eza.tar.gz
sudo mv eza /usr/local/bin/eza

# stylua
curl -L https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip -o stylua.zip
unzip -o stylua.zip
sudo mv stylua /usr/local/bin/stylua

# buf
curl -L https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64.tar.gz -o buf.tar.gz
tar -xzf buf.tar.gz
sudo mv buf /usr/local/bin/buf

# ripgrep
RIPGREP_VERSION="$(curl -L https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/BurntSushi/ripgrep/releases/download/"${RIPGREP_VERSION}"/ripgrep_"${RIPGREP_VERSION}"-1_amd64.deb -o ripgrep.deb
sudo dpkg -i ripgrep.deb

# fd
FD_VERSION="$(curl -L https://api.github.com/repos/sharkdp/fd/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/sharkdp/fd/releases/download/"${FD_VERSION}"/fd_"${FD_VERSION:1}"_amd64.deb -o fd.deb
sudo dpkg -i fd.deb

# fzf
FZF_VERSION="$(curl -L https://api.github.com/repos/junegunn/fzf/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/junegunn/fzf/releases/download/v"${FZF_VERSION}"/fzf-"${FZF_VERSION}"-linux_amd64.tar.gz -o fzf.tar.gz
tar -xzf fzf.tar.gz
sudo mv fzf /usr/local/bin/fzf

# shfmt
SHFMT_VERSION="$(curl -L https://api.github.com/repos/mvdan/sh/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/mvdan/sh/releases/download/"${SHFMT_VERSION}"/shfmt_"${SHFMT_VERSION}"_linux_amd64 -o shfmt
chmod +x shfmt
sudo mv shfmt /usr/local/bin/shfmt

# gopls
/opt/go/bin/go install golang.org/x/tools/gopls@latest

popd # $INSTALL_TMPDIR

rm -rf "$INSTALL_TMPDIR"

##### Shell #####

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
