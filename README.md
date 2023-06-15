# Scripts

A bunch of configs, tools and install scripts I use on every machine I set up. This repo is named `scripts` mostly for historical reasons.

## Installation

### Arch Linux

Follow the instructions in `install/arch/setup.txt` to kick off the installation from the ISO and run `make -C install`.

### MacOS

Give Terminal Full Disk Access and run the `install/macos/install.sh` script.

## Post-installation

- On MacOS, codesign Alacritty by running `codesign-alacritty` and give it Full Disk Access and Developer Tools support by going to "System Settings" > "Privacy & Security" > "Full Disk Access" / "Developer Tools"
- Neovim needs some language providers to be installed manually (check with `nvim +checkhealth`):
    - `python3 -m pip install --upgrade pynvim`
    - `npm install -g neovim`
- Check health of a few Neovim plugins and make sure that the appropriate packages are installed:
    - `nvim +checkhealth lazy`
    - `nvim +checkhealth mason`
    - `nvim +checkhealth null-ls`

## Maintenance

- Periodically update the shell plugins by running `update-shell-plugins`.
