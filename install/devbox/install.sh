#!/bin/bash

set -eu -o pipefail

# NOTE: This script is idempotent and can be run multiple times to update
# toolchains or programs to the latest version.

export DEBIAN_FRONTEND=noninteractive

export PATH="$HOME/.local/bin:$PATH"

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains" && mkdir -p "$XDG_TOOLCHAINS_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf "$INSTALL_TMPDIR"' EXIT

###################################
############## User ###############
###################################

if [ "$(id -u)" -ne 0 ]; then
  sudo adduser "$USER" sudo
  echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/90-nopasswd-${USER}" >/dev/null
  sudo chmod 0440 "/etc/sudoers.d/90-nopasswd-${USER}"
fi

###################################
########## Base Packages ##########
###################################

# These are the base packages necessary to install/build other things on the
# system and for which we don't really need the very latest version and can live
# with whatever version the current distro happens to package.

sudo apt-get update

sudo apt-get -y install \
  bubblewrap \
  build-essential \
  clang-format \
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

LINUXBREW_USER="linuxbrew"
LINUXBREW_HOME="/home/${LINUXBREW_USER}"
LINUXBREW_PATH="${LINUXBREW_HOME}/.linuxbrew"
BREW_BIN="$LINUXBREW_PATH/bin/brew"
BREWFILE="$HOME/scripts/config/linux/.config/homebrew/Brewfile.devbox"

ensure_linuxbrew_user() {
  if ! id -u "$LINUXBREW_USER" >/dev/null 2>&1; then
    sudo useradd --create-home --home-dir "$LINUXBREW_HOME" --shell /bin/bash "$LINUXBREW_USER"
  fi

  sudo mkdir -p /etc/sudoers.d "$LINUXBREW_HOME"
  sudo chown -R "$LINUXBREW_USER:$LINUXBREW_USER" "$LINUXBREW_HOME"
  echo "${LINUXBREW_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/90-nopasswd-${LINUXBREW_USER}" >/dev/null
  sudo chmod 0440 "/etc/sudoers.d/90-nopasswd-${LINUXBREW_USER}"
}

linuxbrew() {
  sudo runuser -u "$LINUXBREW_USER" -- env HOME="$LINUXBREW_HOME" NONINTERACTIVE=1 "$@"
}

ensure_linuxbrew_user

[ -x "$BREW_BIN" ] || linuxbrew /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

BREWFILE_TMP=$(mktemp /tmp/devbox-brewfile.XXXXXX)
cp "$BREWFILE" "$BREWFILE_TMP"
chmod 0644 "$BREWFILE_TMP"

export PATH="$LINUXBREW_PATH/bin:$LINUXBREW_PATH/sbin:$PATH"

pushd /home/linuxbrew

linuxbrew "$BREW_BIN" update
linuxbrew "$BREW_BIN" bundle install --file="$BREWFILE_TMP" --upgrade --cleanup

popd

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
export PY_TOOLCHAIN_BIN="$XDG_TOOLCHAINS_HOME/python/uv/bin"
export VENV_INSTALL_DIR="$XDG_TOOLCHAINS_HOME/python/venv" && mkdir -p "$VENV_INSTALL_DIR"
"$HOME/scripts/bin/common/.local/bin/pyswitch" latest

# rust
mkdir -p "$XDG_TOOLCHAINS_HOME/rust"
export CARGO_HOME="$XDG_TOOLCHAINS_HOME/rust/cargo"
export RUSTUP_HOME="$XDG_TOOLCHAINS_HOME/rust/rustup"
[ -d "$RUSTUP_HOME" ] || curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=none -y --no-modify-path --no-update-default-toolchain
"$CARGO_HOME/bin/rustup" component add rust-src rustfmt clippy
"$HOME/scripts/bin/common/.local/bin/rustswitch" latest

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
export TF_INSTALL_PATH="$XDG_TOOLCHAINS_HOME/terraform"
export TF_BINARY_PATH="$HOME/.local/bin/terraform"
tfswitch --latest

export PATH="$CARGO_HOME/bin:$PY_TOOLCHAIN_BIN:$GO_TOOLCHAIN_BIN:$GOBIN:$NODE_TOOLCHAIN_BIN:$PATH"

###################################
############## Shell ##############
###################################

FISH_BIN="$LINUXBREW_PATH/bin/fish"

# Change shell to fish
if ! grep -q "$FISH_BIN" /etc/shells; then
  printf '%s\n' "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null
fi
[ "$SHELL" == "$FISH_BIN" ] || sudo chsh "$USER" --shell "$FISH_BIN"

# Run stow to put all the configs and bins in the right place.
"$HOME/scripts/bin/common/.local/bin/stow-config"

# Install shell plugins
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins" --no-update

###################################
############## Codex ##############
###################################

# Needed by bubblewrap in codex to create users.
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | sudo tee /etc/sysctl.d/20-apparmor-donotrestrict.conf
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

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
ExecStart=%h/scripts/install/devbox/install.sh
Restart=no

[Install]
WantedBy=default.target
EOF

# Enabling the service simply creates a symlink in $SYSTEMD_HOME so it will persist
# across reboots when only the home volume is preserved.
systemctl --user enable "$DEVBOX_SERVICE"
