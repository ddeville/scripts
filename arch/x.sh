#!/bin/bash

sudo pacman -Syy

sudo pacman -S --needed \
    xorg xorg-xinit lxappearance \
    bspwm sxhkd slock lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    flatpak dunst nautilus redshift firefox-developer-edition neofetch dmenu rofi sxiv mupdf \
    libvncserver remmina \
    alacritty neovim stow bat exa fish htop jq ripgrep tmux curl fd go ninja nodejs npm \
    ttf-anonymous-pro xorg-fonts-misc terminus-font noto-fonts noto-fonts-emoji ttf-dejavu ttf-liberation

sudo systemctl enable lightdm

tmp_dir=$(mktemp -d -t yay-XXXXXXXXXX)
pushd $tmp_dir
git clone https://aur.archlinux.org/yay-git.git
pushd yay-git
makepkg -si
popd
popd

yay -S --needed \
    polybar google-chrome dropbox 1password \
    ttf-unifont otf-public-sans ttf-font-awesome
