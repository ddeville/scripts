#!/bin/sh

sudo pacman -Syy

sudo pacman -S --needed \
    xorg xorg-xinit lxappearance \
    bspwm sxhkd slock lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    dunst redshift neofetch playerctl rofi \
    alacritty firefox-developer-edition nautilus sxiv mupdf remmina \
    faenza-icon-theme papirus-icon-theme \
    ttf-anonymous-pro ttf-liberation inter-font ttf-dejavu noto-fonts noto-fonts-emoji tex-gyre-fonts gnu-free-fonts xorg-fonts-misc ttf-linux-libertine

yay -S --needed \
    polybar \
    ttf-nunito montserrat-font-ttf otf-public-sans ttf-mac-fonts ttf-font-awesome

sudo systemctl enable lightdm
