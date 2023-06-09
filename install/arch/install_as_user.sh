#!/bin/bash

set -eu

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

cd "$HOME"

# Make fish the default shell
chsh --shell /usr/bin/fish

# Paru needs `rust` but since we install `rustup` rather than `rust` we need to install a toolchain manually
rustup default stable
rustup component add rust-src rustfmt clippy

# Install Paru
if ! command -v paru &>/dev/null; then
  git clone --depth=1 https://aur.archlinux.org/paru.git paru
  pushd paru || exit 1
  makepkg -si
  popd || exit 1
  rm -rf paru
fi

# Install the 1Password signing key that we will need to install the package
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import

# Install AUR packages with Paru
readarray -t aur_packages < <(grep -Ev "^#|^$" "scripts/install/arch/aur_packages.txt")
paru -Syy
paru -S --needed "${aur_packages[@]}"

# Run stow to put all the configs and bins in the right place (making sure to first delete a couple of
# configs that might have been created and that would prevent stow from completing successfully)
rm -f .bashrc .profile
scripts/bin/common/.local/bin/stow-config

# Setup the shell plugins
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export TMUX_PLUGIN_MANAGER_PATH="$XDG_DATA_HOME/tmux/plugins"
scripts/bin/common/.local/bin/update-shell-plugins
