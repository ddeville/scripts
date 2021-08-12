# Scripts

A bunch of configs and scripts I use on every machine I set up. This repo is named `scripts` mostly for historical reasons.

The install script used to be cross-platform and written in Python. I've since then decided that maintaining it was a
pain and switched to simple shell scripts to do the original installation and more scripts to automate the updates later on.
The legacy installer can still be found under `install/legacy`.

## Installation

### Arch Linux

Follow the instructions in `install/arch/setup.txt` to kick off the installation from the ISO.
Then, run `base.sh`, `x.sh` and `progs.sh` in that order.

### MacOS

Run the `install/macos/install.sh` script.

Also manually install iTerm2 and whatever other GUI programs necessary.

## Post-installation

- Stow the various config files by running `bin/common/stow-config`.
- Add the rust source and linters to the rustup install: `rustup component add rust-src rustfmt clippy`.
- Install the nightly Neovim by running `nvim-nightly-install`.
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python2 -m pip install --upgrade pynvim`
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
- Install the various LSP servers by running `lsp-install`.
- Rehash the `pyenv` shims by running `pyenv rehash shell` (and install latest python version).

## Maintenance

- Periodically update the shell plugins by running `update-shell-plugins`.
- Periodically update the LSP binaries by running `lsp-install`.
