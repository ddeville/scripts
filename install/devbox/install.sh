#!/bin/bash

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "The script is running as root, please run as a the user."
  exit 1
fi

cd "$HOME"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"

# Latest packages
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt-add-repository ppa:fish-shell/release-3 -y

# Current LTS nodejs
curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -

sudo apt-get update

sudo apt-get -y install black \
  clang-format \
  cmake \
  curl \
  fish \
  gcc \
  gdb \
  gh \
  git \
  htop \
  isort \
  jq \
  ninja-build \
  nodejs \
  stow \
  tmux \
  vim \
  wget

# Latest nvim
curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz -o nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
sudo mv /opt/nvim-linux64 /opt/nvim
rm nvim-linux64.tar.gz

# Latest bazelisk
curl -L https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 -o bazelisk
chmod +x bazelisk
sudo mv bazelisk /usr/local/bin/bazel

# Latest fzf
FZF_VERSION=0.54.3
curl -L https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz -o fzf.tar.gz
tar -xzf fzf.tar.gz
rm fzf.tar.gz
sudo mv fzf /usr/local/bin/fzf

# Latest ripgrep
RIPGREP_VERSION=14.1.0
curl -LO https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}-1_amd64.deb
sudo dpkg -i ripgrep_${RIPGREP_VERSION}-1_amd64.deb
rm ripgrep_${RIPGREP_VERSION}-1_amd64.deb

# Latest fd
FD_VERSION=10.1.0
curl -LO https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd_${FD_VERSION}_amd64.deb
sudo dpkg -i fd_${FD_VERSION}_amd64.deb
rm fd_${FD_VERSION}_amd64.deb

# Latest golang
GOLANG_VERSION=1.22.2
curl -L https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz -o go.tar.gz
sudo rm -rf /opt/go
sudo tar -C /opt -xzf go.tar.gz
rm go.tar.gz

# Latest rust
RUST_VERSION=1.76.0
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
curl --proto '=https' --tlsv1.2 -sSLf https://sh.rustup.rs | /bin/sh -s -- --default-toolchain=${RUST_VERSION} -y --no-modify-path
"$XDG_DATA_HOME/cargo/bin/rustup" default stable
"$XDG_DATA_HOME/cargo/bin/rustup" component add rust-src rustfmt clippy

# Install a few programs
export PATH="/opt/nvim/bin:/opt/go/bin:$XDG_DATA_HOME/cargo/bin:$PATH"

go install golang.org/x/tools/gopls@latest
go install github.com/bazelbuild/buildtools/buildifier@latest
go install github.com/bufbuild/buf/cmd/buf@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest

cargo install eza
cargo install stylua

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
