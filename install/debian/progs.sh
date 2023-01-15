#!/bin/bash

# Can be overriden from the command line
: "${USERNAME:=damien}"

sudo apt-get install \
  fish vim neovim stow bat htop jq ripgrep tmux curl fd-find cmake golang gdb exa zoxide

echo "$USERNAME ALL=(ALL) ALL" | sudo tee -a /etc/sudoers.d/"$USERNAME" >/dev/null

chsh -s /usr/bin/fish

"$SCRIPT_DIR"/../../bin/common/.local/bin/update-shell-plugins

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
