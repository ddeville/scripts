#!/bin/sh

# Can be overriden from the command line
: "${USERNAME:=damien}"

sudo apt-get install \
  fish vim neovim stow bat htop jq ripgrep tmux curl fd-find cmake golang gdb exa zoxide

echo "$USERNAME ALL=(ALL) ALL" | sudo tee -a /etc/sudoers.d/"$USERNAME" >/dev/null

chsh -s /usr/bin/fish

git clone https://github.com/tinted-theming/base16-shell.git ~/.local/share/base16-shell
git clone https://github.com/tmux-plugins/tpm ~/scripts/config/common/.config/tmux/plugins/tpm

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
