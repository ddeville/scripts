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
  jq \
  stow \
  unzip \
  xz-utils

###################################
############# Tools ###############
###################################

download_latest_github_asset() {
  local asset asset_template release repo tag url version

  repo=$1
  asset_template=$2

  release=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")
  tag=$(jq -er '.tag_name' <<<"$release")
  version=${tag#v}
  asset=${asset_template//\{version\}/$version}

  if ! url=$(jq -er --arg asset "$asset" 'first(.assets[] | select(.name == $asset) | .browser_download_url)' <<<"$release"); then
    echo "no latest release asset found for $repo named $asset" >&2
    exit 1
  fi

  echo "downloading $asset" >&2
  curl -fsSL -o "$asset" "$url"

  printf '%s\n' "$asset"
}

ARCH=$(uname -m)

# tmux

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x86_64)
archive=$(download_latest_github_asset tmux/tmux-builds "tmux-{version}-linux-${arch}.tar.gz")
tar -xzf "$archive"
sudo install -m 0755 tmux /usr/local/bin/tmux

# fish

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
archive=$(download_latest_github_asset fish-shell/fish-shell "fish-{version}-linux-${arch}.tar.xz")
tar -xJf "$archive"
sudo install -m 0755 fish /usr/local/bin/fish

# neovim

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x86_64)
archive=$(download_latest_github_asset neovim/neovim "nvim-linux-${arch}.tar.gz")
sudo tar -xzf "$archive" --strip-components=1 -C /usr/local

# tree-sitter

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo x64)
archive=$(download_latest_github_asset tree-sitter/tree-sitter "tree-sitter-cli-linux-${arch}.zip")
unzip -q "$archive"
sudo install -m 0755 tree-sitter /usr/local/bin/tree-sitter

# fzf

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo arm64 || echo amd64)
archive=$(download_latest_github_asset junegunn/fzf "fzf-{version}-linux_${arch}.tar.gz")
tar -xzf "$archive"
sudo install -m 0755 fzf /usr/local/bin/fzf

# ripgrep

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
archive=$(download_latest_github_asset BurntSushi/ripgrep "ripgrep-{version}-${arch}-unknown-linux-musl.tar.gz")
tar -xzf "$archive"
sudo install -m 0755 ripgrep-*/rg /usr/local/bin/rg

# fd

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
archive=$(download_latest_github_asset sharkdp/fd "fd-v{version}-${arch}-unknown-linux-musl.tar.gz")
tar -xzf "$archive"
sudo install -m 0755 fd-*/fd /usr/local/bin/fd

# eza

arch=$([[ $ARCH == arm64 || $ARCH == aarch64 ]] && echo aarch64 || echo x86_64)
archive=$(download_latest_github_asset eza-community/eza "eza_${arch}-unknown-linux-musl.tar.gz")
tar -xzf "$archive"
sudo install -m 0755 eza /usr/local/bin/eza

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

sudo apt install --yes bubblewrap

# Needed by bubblewrap in codex to create users.
echo 'kernel.apparmor_restrict_unprivileged_userns = 0' | sudo tee /etc/sysctl.d/20-apparmor-donotrestrict.conf
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
