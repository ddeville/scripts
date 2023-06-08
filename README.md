# Scripts

A bunch of configs, tools and install scripts I use on every machine I set up. This repo is named `scripts` mostly for historical reasons.

## Installation

### Arch Linux

Follow the instructions in `install/arch/setup.txt` to kick off the installation from the ISO and run the `install/arch/install.sh` script.

### MacOS

Run the `install/macos/install.sh` script.

## Post-installation

- Stow the various config files by running `bin/stow-config`.
- Install the shell plugins by running `update-shell-plugins`.
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
- Install the various LSP servers by running `lsp-install`.
- Rehash the `pyenv` shims by running `pyenv rehash shell` (and install latest python version).
- On MacOS, codesign Alacritty by running `codesign-alacritty` and give it Full Disk Access and Developer Tools support by going to "System Settings" > "Privacy & Security" > "Full Disk Access" / "Developer Tools"

## Maintenance

- Periodically update the shell plugins by running `update-shell-plugins`.
- Periodically update the LSP binaries by running `lsp-install`.
