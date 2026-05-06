#!/bin/bash

# NOTE: This script is idempotent and can be run multiple times to update
# toolchains or programs to the latest version.

export DEBIAN_FRONTEND=noninteractive

###################################
############## User ###############
###################################

if [ "$(id -u)" -ne 0 ]; then
  sudo adduser "$USER" sudo
  echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/90-nopasswd-${USER}" >/dev/null
  sudo chmod 0440 "/etc/sudoers.d/90-nopasswd-${USER}"
fi

export PATH="$HOME/.local/bin:$PATH"

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"
export XDG_TOOLCHAINS_HOME="$HOME/.local/toolchains" && mkdir -p "$XDG_TOOLCHAINS_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR"
trap 'rm -rf "$INSTALL_TMPDIR"' EXIT

###################################
########## Base Packages ##########
###################################

sudo apt update

sudo apt --yes install \
  curl \
  file \
  git \
  stow \
  unzip \
  xz-utils

###################################
############# Tools ###############
###################################

if [ "$(uname -m)" = "arm64" ]; then
  ARCH=arm64
  LLVM_ARCH=aarch64
  OCI_ARCH=arm64
  WIN_ARCH=arm64
else
  ARCH=x86_64
  LLVM_ARCH=x86_64
  OCI_ARCH=amd64
  WIN_ARCH=x64
fi

NEOVIM_VERSION=0.12.2
curl -fsSLO https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-${ARCH}.tar.gz

FISH_VERSION=4.6.0
curl -fsSLO https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${LLVM_ARCH}.tar.xz

TMUX_VERSION=3.6a
curl -fsSLO https://github.com/tmux/tmux-builds/releases/download/v${TMUX_VERSION}/tmux-${TMUX_VERSION}-linux-${ARCH}.tar.gz

RIPGREP_VERSION=15.1.0
curl -fsSLO https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${LLVM_ARCH}-unknown-linux-musl.tar.gz

FZF_VERSION=0.72.0
curl -fsSLO https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${OCI_ARCH}.tar.gz

FD_VERSION=10.4.2
curl -fsSLO https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${LLVM_ARCH}-unknown-linux-musl.tar.gz

EZA_VERSION=0.23.4
curl -fsSLO https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_${LLVM_ARCH}-unknown-linux-musl.tar.gz

TREE_SITTER_VERSION=0.26.8
curl -fsSLO https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-cli-linux-${WIN_ARCH}.zip

###################################
############## Shell ##############
###################################

FISH_BIN=/usr/local/bin/fish

if ! grep -q "$FISH_BIN" /etc/shells; then
  printf '%s\n' "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null
fi
[ "$SHELL" == "$FISH_BIN" ] || sudo chsh "$USER" --shell "$FISH_BIN"

"$HOME/scripts/bin/common/.local/bin/stow-config"

export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
"$HOME/scripts/bin/common/.local/bin/update-shell-plugins" --no-update

###################################
############## Codex ##############
###################################

sudo apt --yes install bubblewrap

# Needed by bubblewrap in codex to create users.
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | sudo tee /etc/sysctl.d/20-apparmor-donotrestrict.conf
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
