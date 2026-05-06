#!/bin/bash

set -eu -o pipefail

# NOTE: This script is idempotent and can be run multiple times to update
# toolchains or programs to the latest version.

export DEBIAN_FRONTEND=noninteractive

export PATH="$HOME/.local/bin:$PATH"

export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p "$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p "$XDG_DATA_HOME"
export XDG_STATE_HOME="$HOME/.local/state" && mkdir -p "$XDG_STATE_HOME"

INSTALL_TMPDIR="$(mktemp -d)"
cd "$INSTALL_TMPDIR" || exit
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

sudo apt update

sudo apt install --yes \
  curl \
  file \
  git \
  stow \
  unzip \
  xz-utils

###################################
############# Tools ###############
###################################

ARCH=$(uname -m)

NEOVIM_VERSION=0.12.2
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x86_64)
curl -fsSLO "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-${arch}.tar.gz"
sudo tar -xzf "nvim-linux-${arch}.tar.gz" --strip-components=1 -C /usr/local

FISH_VERSION=4.6.0
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
curl -fsSLO "https://github.com/fish-shell/fish-shell/releases/download/${FISH_VERSION}/fish-${FISH_VERSION}-linux-${arch}.tar.xz"
tar -xJf "fish-${FISH_VERSION}-linux-${arch}.tar.xz"
sudo install -m 0755 fish /usr/local/bin/fish

TMUX_VERSION=3.6a
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x86_64)
curl -fsSLO "https://github.com/tmux/tmux-builds/releases/download/v${TMUX_VERSION}/tmux-${TMUX_VERSION}-linux-${arch}.tar.gz"
tar -xzf "tmux-${TMUX_VERSION}-linux-${arch}.tar.gz"
sudo install -m 0755 tmux /usr/local/bin/tmux

RIPGREP_VERSION=15.1.0
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
curl -fsSLO "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${arch}-unknown-linux-musl.tar.gz"
tar -xzf "ripgrep-${RIPGREP_VERSION}-${arch}-unknown-linux-musl.tar.gz"
sudo install -m 0755 "ripgrep-${RIPGREP_VERSION}-${arch}-unknown-linux-musl/rg" /usr/local/bin/rg

FZF_VERSION=0.72.0
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo amd64)
curl -fsSLO "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${arch}.tar.gz"
tar -xzf "fzf-${FZF_VERSION}-linux_${arch}.tar.gz"
sudo install -m 0755 fzf /usr/local/bin/fzf

FD_VERSION=10.4.2
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
curl -fsSLO "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${arch}-unknown-linux-musl.tar.gz"
tar -xzf "fd-v${FD_VERSION}-${arch}-unknown-linux-musl.tar.gz"
sudo install -m 0755 "fd-v${FD_VERSION}-${arch}-unknown-linux-musl/fd" /usr/local/bin/fd

EZA_VERSION=0.23.4
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
curl -fsSLO "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_${arch}-unknown-linux-musl.tar.gz"
tar -xzf "eza_${arch}-unknown-linux-musl.tar.gz"
sudo install -m 0755 eza /usr/local/bin/eza

TREE_SITTER_VERSION=0.26.8
arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x64)
curl -fsSLO "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/tree-sitter-cli-linux-${arch}.zip"
unzip -q "tree-sitter-cli-linux-${arch}.zip"
sudo install -m 0755 tree-sitter /usr/local/bin/tree-sitter

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
