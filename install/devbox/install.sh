#!/bin/bash

set -euo pipefail

# NOTE: This script is idempotent and can be run multiple times to update toolchains or
# programs to the latest version.

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

#########################
####### Versions ########
#########################

PYTHON_VERSION=3.11.8
RUST_VERSION=1.76.0
GOLANG_VERSION=1.22.2
NODE_VERSION=22.6.0
TERRAFORM_VERSION=1.6.4

#########################
######### Setup #########
#########################

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains" && mkdir -p "$XDG_TOOLCHAINS_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf $INSTALL_TMPDIR' EXIT

PREFIX=/usr/local

#########################
##### Base Packages #####
#########################

# These are the base packages necessary to install/build other things on the system and for
# which we don't really need the very latest version and can live with whatever version the
# current distro happens to package.
#
# Note that for packages that have a ppa that tracks the latest version we opt for installing
# the packages this way rather than building them ourself.

sudo add-apt-repository universe -y
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-add-repository ppa:fish-shell/release-3 -y

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
  git \
  htop \
  jq \
  libbz2-dev \
  libevent-dev \
  libffi-dev \
  liblzma-dev \
  libncurses-dev \
  libncursesw5-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  ninja-build \
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

# Install language build toolchains.
#
# The idea with all of them is to install a toolchain manager (pyenv, rustup, tfswitch, etc...) that can
# then be used to install a given version of the actual toolchain and point the PATH to it.
# Toolchains get installed in the `~/.local/toolchains` directory and things get added to the PATH in the
# usual fish path handling function.

# python
mkdir -p "$XDG_TOOLCHAINS_HOME/python"
export PYENV_ROOT="$XDG_TOOLCHAINS_HOME/python/pyenv"
[ -d "$PYENV_ROOT" ] || curl -L https://pyenv.run | bash
"$PYENV_ROOT/bin/pyenv" update
"$PYENV_ROOT/bin/pyenv" install --skip-existing "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" global "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" rehash

# rust
mkdir -p "$XDG_TOOLCHAINS_HOME/rust"
export CARGO_HOME="$XDG_TOOLCHAINS_HOME/rust/cargo"
export RUSTUP_HOME="$XDG_TOOLCHAINS_HOME/rust/rustup"
[ -d "$RUSTUP_HOME" ] || curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=${RUST_VERSION} -y --no-modify-path
"$CARGO_HOME/bin/rustup" toolchain "$RUST_VERSION"
"$CARGO_HOME/bin/rustup" default stable
"$CARGO_HOME/bin/rustup" component add rust-src rustfmt clippy

# golang
mkdir -p "$XDG_TOOLCHAINS_HOME/go"
export GO_TOOLCHAIN_BIN="$XDG_TOOLCHAINS_HOME/go/current/bin"
export GOBIN="$XDG_TOOLCHAINS_HOME/go/user/bin"
"$HOME/scripts/bin/common/.local/bin/goswitch" $GOLANG_VERSION

# nodejs
mkdir -p "$XDG_TOOLCHAINS_HOME/node"
export NODE_TOOLCHAIN_BIN="$XDG_TOOLCHAINS_HOME/node/current/bin"
"$HOME/scripts/bin/common/.local/bin/nodeswitch" $NODE_VERSION

# terraform
mkdir -p "$XDG_TOOLCHAINS_HOME/terraform"
curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/master/install.sh | bash -s -- -b "$HOME/.local/bin"
"$HOME/.local/bin/tfswitch" --install "$XDG_TOOLCHAINS_HOME/terraform" --bin "$HOME/.local/bin/terraform" "$TERRAFORM_VERSION"

export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$CARGO_HOME/bin:$GO_TOOLCHAIN_BIN:$GOBIN:$NODE_TOOLCHAIN_BIN:$PATH"

#########################
####### Programs ########
#########################

# Install latest version of specific programs. These programs are pretty critical to day-to-day
# workflows and having the latest version is either highly recommended or even required.
#
# Note that this started with a couple of programs and thus installing them manually made sense
# but now that the list has grown it might be beneficial to switch to linuxbrew...

# TODO(damien): Switch dpkg install to regular packages

# neovim
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz -o nvim-linux64.tar.gz
sudo tar -xzf nvim-linux64.tar.gz -C "$PREFIX" --strip-components 1

# tmux
curl -L "$(curl -L https://api.github.com/repos/tmux/tmux/releases/latest | jq --raw-output '.assets[0].browser_download_url')" -o tmux.tar.gz
mkdir -p tmux && tar -xzf tmux.tar.gz -C tmux --strip-components 1
./tmux/configure --prefix="$PREFIX" && make -C tmux && sudo make -C tmux install

# fzf
FZF_VERSION="$(curl -L https://api.github.com/repos/junegunn/fzf/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/junegunn/fzf/releases/download/v"${FZF_VERSION}"/fzf-"${FZF_VERSION}"-linux_amd64.tar.gz -o fzf.tar.gz
sudo tar -xzf fzf.tar.gz -C "$PREFIX/bin"
# TODO(damien): there's a man page in the repo, we can download the latest source and copy it over

# ripgrep
RIPGREP_VERSION="$(curl -L https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/BurntSushi/ripgrep/releases/download/"${RIPGREP_VERSION}"/ripgrep_"${RIPGREP_VERSION}"-1_amd64.deb -o ripgrep.deb
sudo dpkg -i ripgrep.deb

# fd
FD_VERSION="$(curl -L https://api.github.com/repos/sharkdp/fd/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/sharkdp/fd/releases/download/"${FD_VERSION}"/fd_"${FD_VERSION:1}"_amd64.deb -o fd.deb
sudo dpkg -i fd.deb

# eza
curl -L https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -o eza.tar.gz
sudo tar -xzf eza.tar.gz -C "$PREFIX/bin"

# btop
curl -L https://github.com/aristocratos/btop/releases/latest/download/btop-x86_64-linux-musl.tbz -o btop.tbz
tar -xjf btop.tbz
PREFIX=$PREFIX sudo make install -C btop

# gh
GH_VERSION="$(curl -L https://api.github.com/repos/cli/cli/releases/latest | jq --raw-output '.tag_name')"
curl -L https://github.com/cli/cli/releases/download/"${GH_VERSION}"/gh_"${GH_VERSION:1}"_linux_amd64.deb -o gh.deb
sudo dpkg -i gh.deb

# bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o bazel
chmod +x bazel && sudo mv bazel "$PREFIX"/bin/bazel

# buf
curl -L https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64.tar.gz -o buf.tar.gz
sudo tar -xzf buf.tar.gz -C "$PREFIX" --strip-components 1

# buildifier
curl -L https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-amd64 -o buildifier
chmod +x buildifier && sudo mv buildifier "$PREFIX"/bin/buildifier

# stylua
curl -L https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip -o stylua.zip
unzip -o stylua.zip && sudo mv stylua "$PREFIX"/bin/stylua

# shfmt
SHFMT_VERSION="$(curl -L https://api.github.com/repos/mvdan/sh/releases/latest | jq --raw-output '.name')"
curl -L https://github.com/mvdan/sh/releases/download/"${SHFMT_VERSION}"/shfmt_"${SHFMT_VERSION}"_linux_amd64 -o shfmt
chmod +x shfmt && sudo mv shfmt "$PREFIX"/bin/shfmt

# gopls
"$XDG_TOOLCHAINS_HOME/go/current/bin/go" install golang.org/x/tools/gopls@latest

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
