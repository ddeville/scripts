#!/bin/bash

set -eu -o pipefail

# NOTE: This script is idempotent and can be run multiple times to update
# toolchains or programs to the latest version.

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as the user."
  exit 1
fi

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains" && mkdir -p "$XDG_TOOLCHAINS_HOME"
export VENV_INSTALL_DIR="$XDG_TOOLCHAINS_HOME/python/venv" && mkdir -p "$VENV_INSTALL_DIR"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf "$INSTALL_TMPDIR"' EXIT

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

LINUXBREW_PATH="/home/linuxbrew/.linuxbrew"
BREW_BIN="$LINUXBREW_PATH/bin/brew"

[ -x "$BREW_BIN" ] || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

"$BREW_BIN" update
"$BREW_BIN" bundle install --file="$HOME/scripts/config/linux/.config/homebrew/Brewfile.devbox" --upgrade --cleanup

export PATH="$LINUXBREW_PATH/bin:$LINUXBREW_PATH/sbin:$PATH"

###################################
########### Toolchains ############
###################################

# Install language build toolchains.
#
# For each toolchain, the idea is to install a toolchain manager (uv, rustup,
# tfswitch, etc...) that can then be used to install a given version of the
# actual toolchain and point the PATH to it.
# Toolchains get installed in the `~/.local/toolchains` directory and things
# get added to the PATH in the usual fish path handling function.

# python
mkdir -p "$XDG_TOOLCHAINS_HOME/python"
export PATH="$HOME/.local/bin:$PATH"
"$HOME/scripts/bin/common/.local/bin/pyswitch" latest

# rust
mkdir -p "$XDG_TOOLCHAINS_HOME/rust"
export CARGO_HOME="$XDG_TOOLCHAINS_HOME/rust/cargo"
export RUSTUP_HOME="$XDG_TOOLCHAINS_HOME/rust/rustup"
[ -d "$RUSTUP_HOME" ] || curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=none -y --no-modify-path --no-update-default-toolchain
"$CARGO_HOME/bin/rustup" toolchain install stable
"$CARGO_HOME/bin/rustup" default stable
"$CARGO_HOME/bin/rustup" component add rust-src rustfmt clippy

# golang
mkdir -p "$XDG_TOOLCHAINS_HOME/go"
export GO_TOOLCHAIN_BIN="$XDG_TOOLCHAINS_HOME/go/current/bin"
export GOBIN="$XDG_TOOLCHAINS_HOME/go/user/bin"
"$HOME/scripts/bin/common/.local/bin/goswitch" latest

# nodejs
mkdir -p "$XDG_TOOLCHAINS_HOME/node"
export NODE_TOOLCHAIN_BIN="$XDG_TOOLCHAINS_HOME/node/current/bin"
"$HOME/scripts/bin/common/.local/bin/nodeswitch" latest

# terraform
mkdir -p "$XDG_TOOLCHAINS_HOME/terraform"
curl -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/master/install.sh | /bin/bash -s -- -b "$HOME/.local/bin"
"$HOME/.local/bin/tfswitch" --install "$XDG_TOOLCHAINS_HOME/terraform" --bin "$HOME/.local/bin/terraform" --latest

export PATH="$CARGO_HOME/bin:$GO_TOOLCHAIN_BIN:$GOBIN:$NODE_TOOLCHAIN_BIN:$PATH"

###################################
############## Shell ##############
###################################

FISH_BIN="$LINUXBREW_PATH/bin/fish"

# Change shell to fish
if ! grep -q "$FISH_BIN" /etc/shells; then
  sudo sh -c "echo $FISH_BIN >> /etc/shells"
fi
[ "$SHELL" == "$FISH_BIN" ] || sudo chsh "$USER" --shell "$FISH_BIN"

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

SYSTEMD_HOME="$XDG_CONFIG_HOME/systemd/user"
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
