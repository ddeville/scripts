#!/bin/bash

set -euo pipefail

# NOTE: This script is idempotent and can be run multiple times to update
# toolchains or programs to the latest version.

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as the user."
  exit 1
fi

###################################
####### Toolchain versions ########
###################################

PYTHON_VERSION=3.11.8
RUST_VERSION=1.76.0
GOLANG_VERSION=1.22.2
NODE_VERSION=22.6.0
TERRAFORM_VERSION=1.6.4

###################################
############## Setup ##############
###################################

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains" && mkdir -p "$XDG_TOOLCHAINS_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf $INSTALL_TMPDIR' EXIT

###################################
########## Base Packages ##########
###################################

# These are the base packages necessary to install/build other things on the
# system and for which we don't really need the very latest version and can live
# with whatever version the current distro happens to package.

sudo apt-get update

sudo apt-get -y install \
  build-essential \
  cmake \
  curl \
  file \
  git \
  libbz2-dev \
  libncursesw5-dev \
  libffi-dev \
  liblzma-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  ninja-build \
  pkg-config \
  procps \
  stow \
  tk-dev \
  unzip \
  vim \
  wget \
  xz-utils \
  zlib1g-dev

###################################
############ Homebrew #############
###################################

BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [ ! -x "$BREW_BIN" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

"$BREW_BIN" update

###################################
########### Toolchains ############
###################################

# Install language build toolchains.
#
# For each toolchain, the idea is to install a toolchain manager (pyenv, rustup,
# tfswitch, etc...) that can then be used to install a given version of the
# actual toolchain and point the PATH to it.
# Toolchains get installed in the `~/.local/toolchains` directory and things
# get added to the PATH in the usual fish path handling function.

# python
mkdir -p "$XDG_TOOLCHAINS_HOME/python"
export PYENV_ROOT="$XDG_TOOLCHAINS_HOME/python/pyenv"
[ -d "$PYENV_ROOT" ] || curl -L https://pyenv.run | bash
[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ] || git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
export PYTHON_CONFIGURE_OPTS="--enable-optimizations --with-lto --disable-shared"
export PYTHON_CFLAGS="-march=native -mtune=native"
"$PYENV_ROOT/bin/pyenv" update
"$PYENV_ROOT/bin/pyenv" install --skip-existing "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" global "$PYTHON_VERSION"
"$PYENV_ROOT/bin/pyenv" rehash

# rust
mkdir -p "$XDG_TOOLCHAINS_HOME/rust"
export CARGO_HOME="$XDG_TOOLCHAINS_HOME/rust/cargo"
export RUSTUP_HOME="$XDG_TOOLCHAINS_HOME/rust/rustup"
[ -d "$RUSTUP_HOME" ] || curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=none -y --no-modify-path --no-update-default-toolchain
"$CARGO_HOME/bin/rustup" toolchain install "$RUST_VERSION"
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

###################################
############ Programs #############
###################################

# Install latest version of specific programs. These programs are pretty
# critical to day-to-day development workflows and having the latest version
# is either highly recommended or even required, which is why we install them
# with Homebrew rather than the local (outdated) package manager.

# Shell programs
"$BREW_BIN" install \
  bazelisk \
  btop \
  curl \
  difftastic \
  eza \
  fd \
  fish \
  fzf \
  gh \
  git \
  htop \
  jq \
  neovim \
  ripgrep \
  tmux

# Formatters
"$BREW_BIN" install \
  black \
  buildifier \
  buf \
  clang-format \
  gopls \
  isort \
  ruff \
  shellcheck \
  shfmt \
  stylua

# Update all Brew formulas in case it's not the first time we run this script.
"$BREW_BIN" upgrade

# NOTE: Homebrew links a ton of dependencies into the main bin folder, which is
# not necessarily something that we want since we want to use the programs from
# the distro (which mimics what we actually run everywhere) and only use the
# newer versions for things that we specifically install.
#
# TODO(damien): We should be able to create a new folder that contains symlinks
# to only the top-level programs we install by querying with "brew leaves".

###################################
############## Shell ##############
###################################

FISH_PATH="/home/linuxbrew/.linuxbrew/bin/fish"

# Change shell to fish
if [ "$SHELL" != "$FISH_PATH" ]; then
  sudo chsh "$USER" --shell "$FISH_PATH"
fi

# Run stow to put all the configs and bins in the right place.
"$HOME/scripts/bin/common/.local/bin/stow-config"

# Install shell plugins
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins" --no-update

###################################
############ Automation ###########
###################################

# Run the script on boot so that it can set up a few global things (like the
# default shell) in scenarios where a devbox is recreated and only its home
# volume is preserved.

SYSTEMD_HOME="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_HOME"

DEVBOX_SERVICE="$SYSTEMD_HOME/setup-devbox.service"

cat <<EOF >"$DEVBOX_SERVICE"
[Unit]
Description=Set up devbox

[Service]
Type=simple
ExecStart=scripts/install/devbox/install.sh
Restart=no

[Install]
WantedBy=default.target
EOF

# Enabling the service simply creates a symlink in $SYSTEMD_HOME so it will persist
# across reboots when only the home volume is preserved.
systemctl --user enable "$DEVBOX_SERVICE"
