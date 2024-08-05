#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

#########################
####### Versions ########
#########################

PYTHON_VERSION=3.11.8
GOLANG_VERSION=1.22.2
RUST_VERSION=1.76.0
NODE_VERSION=setup_20.x

#########################
######### Setup #########
#########################

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf $INSTALL_TMPDIR' EXIT

PREFIX=/usr/local

#########################
##### Base Packages #####
#########################

sudo add-apt-repository universe -y
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-add-repository ppa:fish-shell/release-3 -y
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
  libncurses-dev \
  libevent-dev \
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
  pkg-config \
  stow \
  tk-dev \
  unzip \
  vim \
  wget \
  xz-utils \
  zlib1g-dev

#########################
###### Toolchains #######
#########################

# golang
curl -L https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz -o go.tar.gz
sudo tar -xzf go.tar.gz -C "$PREFIX"

# rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=${RUST_VERSION} -y --no-modify-path
"$XDG_DATA_HOME/cargo/bin/rustup" default stable
"$XDG_DATA_HOME/cargo/bin/rustup" component add rust-src rustfmt clippy

# python
export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
[ -d "$PYENV_ROOT" ] || curl -L https://pyenv.run | bash
"$PYENV_ROOT/bin/pyenv" update
"$PYENV_ROOT/bin/pyenv" install --skip-existing "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" global "$PYTHON_VERSION"

#########################
####### Programs ########
#########################

# neovim
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz -o nvim-linux64.tar.gz
sudo tar -xzf nvim-linux64.tar.gz -C "$PREFIX" --strip-components 1

# tmux
curl -L "$(curl -L https://api.github.com/repos/tmux/tmux/releases/latest | jq --raw-output '.assets[0].browser_download_url')" -o tmux.tar.gz
mkdir -p tmux && tar -xzf tmux.tar.gz -C tmux --strip-components 1
./tmux/configure --prefix="$PREFIX" && make -C tmux && sudo make -C tmux install

# bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o bazel
chmod +x bazel && sudo mv bazel "$PREFIX"/bin/bazel

# buildifier
curl -L https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-amd64 -o buildifier
chmod +x buildifier && sudo mv buildifier "$PREFIX"/bin/buildifier

# eza
curl -L https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -o eza.tar.gz
sudo tar -xzf eza.tar.gz -C "$PREFIX/bin"

# stylua
curl -L https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip -o stylua.zip
unzip -o stylua.zip && sudo mv stylua "$PREFIX"/bin/stylua

# buf
curl -L https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64.tar.gz -o buf.tar.gz
sudo tar -xzf buf.tar.gz -C "$PREFIX" --strip-components 1

# fzf
FZF_VERSION="$(curl -L https://api.github.com/repos/junegunn/fzf/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/junegunn/fzf/releases/download/v"${FZF_VERSION}"/fzf-"${FZF_VERSION}"-linux_amd64.tar.gz -o fzf.tar.gz
sudo tar -xzf fzf.tar.gz -C "$PREFIX/bin"

# ripgrep
RIPGREP_VERSION="$(curl -L https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/BurntSushi/ripgrep/releases/download/"${RIPGREP_VERSION}"/ripgrep_"${RIPGREP_VERSION}"-1_amd64.deb -o ripgrep.deb
sudo dpkg -i ripgrep.deb

# fd
FD_VERSION="$(curl -L https://api.github.com/repos/sharkdp/fd/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/sharkdp/fd/releases/download/"${FD_VERSION}"/fd_"${FD_VERSION:1}"_amd64.deb -o fd.deb
sudo dpkg -i fd.deb

# shfmt
SHFMT_VERSION="$(curl -L https://api.github.com/repos/mvdan/sh/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/mvdan/sh/releases/download/"${SHFMT_VERSION}"/shfmt_"${SHFMT_VERSION}"_linux_amd64 -o shfmt
chmod +x shfmt && sudo mv shfmt "$PREFIX"/bin/shfmt

# gopls
/usr/local/go/bin/go install golang.org/x/tools/gopls@latest

#########################
######### Shell #########
#########################

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
