#!/bin/sh

# Can be overriden from the command line
: ${USERNAME:=damien}

sudo apt-get install \
    fish vim neovim stow bat htop jq ripgrep tmux curl fd-find cmake golang gdb exa zoxide

sudo echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers.d/$USERNAME

chsh -s /usr/bin/fish

git clone https://github.com/ddeville/base16-shell.git ~/.local/share/base16-shell
git clone https://github.com/tmux-plugins/tpm ~/scripts/config/common/.config/tmux/plugins/tpm

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
