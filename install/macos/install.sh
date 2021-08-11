#!/bin/sh

/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

arch_name="$(uname -m)"
if [ "${arch_name}" = "arm64" ]; then
    brew_path=/opt/homebrew/bin
else
    brew_path=/usr/local/bin
fi

$brew_path/brew tap homebrew/cask-fonts
$brew_path/brew install \
    bat exa fish htop jq neovim ripgrep stow tmux fd cmake ninja \
    pyenv golang node robotsandpencils/made/xcodes \
    font-anonymous-pro

echo $brew_path/fish >> /etc/shells
chsh -s $brew_path/fish

mkdir -p $HOME/.local/share

export CARGO_HOME=~/.local/share/cargo
export RUSTUP_HOME=~/.local/share/rustup
curl -fsSL https://sh.rustup.rs | /bin/sh -s -- -y --no-modify-path

git clone https://github.com/ddeville/base16-shell.git ~/.local/share/base16-shell
git clone https://github.com/tmux-plugins/tpm ~/scripts/config/common/.config/tmux/plugins/tpm
