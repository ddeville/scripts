# Scripts

A bunch of configs, tools and install scripts I use on every machine I set up. This repo is named `scripts` mostly for historical reasons.

## Installation

### Arch Linux

Follow the instructions in `install/arch/setup.txt` to kick off the installation from the ISO and run `make -C install`.

### MacOS

Give Terminal Full Disk Access and run the `install/macos/install.sh` script.

## Post-installation

- On MacOS, codesign Alacritty by running `codesign-alacritty` and give it Full Disk Access and Developer Tools support by going to "System Settings" > "Privacy & Security" > "Full Disk Access" / "Developer Tools"
- On Arch Linux, edit `config/linux/.xprofile` and `config/linux/.config/bspwm/bspwmrc` to tweak settings related to the display and overall machine type
- Check health of a few Neovim plugins and make sure that the appropriate packages are installed:
    - `nvim +checkhealth lazy`
    - `nvim +checkhealth mason`
    - `nvim +checkhealth conform`
    - `nvim +checkhealth` to check health of everything at once

### Biometrics on Arch Linux

- Enroll finger `fprintd-enroll damien -f right-index-finger`
- Edit `/etc/pam.d/polkit-1` and add `auth sufficient pam_fprintd.so` to the top
- Repeat with whatever file is appropriate in `/etc/pam.d/*`

## Maintenance

- Run `make -C install shell-plugins` to update the shell plugins.
- Run `make -C install stow` whenever there's a new file that should be symlinked.
- Run `make -C install packages` to install/update all packages.
