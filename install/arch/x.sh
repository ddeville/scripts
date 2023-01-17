#!/bin/bash
set -eu

sudo pacman -Syy

sudo pacman -S --needed \
  xorg xorg-xinit lxappearance \
  bspwm sxhkd polybar slock lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
  dunst redshift neofetch playerctl rofi seahorse \
  maim xclip mate-polkit \
  alacritty firefox nautilus sxiv mupdf remmina virt-manager \
  faenza-icon-theme papirus-icon-theme \
  ttf-anonymous-pro ttf-liberation inter-font ttf-dejavu noto-fonts noto-fonts-emoji \
  tex-gyre-fonts gnu-free-fonts xorg-fonts-misc ttf-linux-libertine ttf-opensans \
  ttf-font-awesome adobe-source-serif-fonts adobe-source-sans-fonts adobe-source-code-pro-fonts

paru -S --needed \
  ttf-nunito montserrat-ttf otf-public-sans ttf-mac-fonts apple-fonts

sudo systemctl enable lightdm
