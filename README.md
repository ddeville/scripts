# Scripts

A bunch of configs, tools and install scripts I use on every machine I set up. This repo is named `scripts` mostly for historical reasons.

## Installation

### Arch Linux

Follow the instructions in `install/arch/setup.txt` to kick off the installation from the ISO and run `make -C install`.

### MacOS

Give Terminal Full Disk Access and run the `install/macos/install.sh` script.

## Post-installation

- On MacOS, use Ghostty as the default terminal and give it Full Disk Access and Developer Tools support by going to "System Settings" > "Privacy & Security" > "Full Disk Access" / "Developer Tools". The installer associates Unix executables with Ghostty.
- On Arch Linux, adjust displays in `config/linux/.config/hypr/hyprland.lua` and workspace assignments in `config/linux/.config/hypr/workspaces.lua`.
- Check health of a few Neovim plugins and make sure that the appropriate packages are installed with `nvim +checkhealth`.

### System configuration on Arch Linux

[install/arch/config/](install/arch/config/) contains the greeter and PAM configuration copied into `/etc` by the Arch installer. Edit the repository files and run `make -C install system-config` to apply changes. Edits made directly to the managed files in `/etc` are overwritten.

Enroll fingerprints separately with `fprintd-enroll damien -f right-index-finger`.

### Backgrounds on Arch Linux

Place images in `/usr/share/backgrounds`, keeping their original extensions, and create these symlinks. The installer creates the directory; images and links are managed manually.

| Path | Used by |
| --- | --- |
| `/usr/share/backgrounds/wallpaper` | Hyprpaper desktop wallpaper |
| `/usr/share/backgrounds/login` | ReGreet login background |
| `/usr/share/backgrounds/lock` | Hyprlock lock background |

For example, `sudo ln -sfn 18.jpg /usr/share/backgrounds/login` selects `18.jpg` as the login background.

Run `systemctl --user restart hyprpaper.service` after changing the wallpaper.

## Maintenance

- Run `make -C install shell-plugins` to update the shell plugins.
- Run `make -C install stow` whenever there's a new file that should be symlinked.
- Run `make -C install packages` to install/update all packages.
- On Arch Linux, run `make -C install system-config` to apply system configuration changes.
