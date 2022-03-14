#!/bin/sh

sudo pacman -Syy

sudo pacman -S --needed \
    xorg xorg-xinit lxappearance \
    bspwm sxhkd slock lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    dunst redshift neofetch playerctl rofi seahorse \
    maim xclip mate-polkit \
    alacritty firefox nautilus sxiv mupdf remmina virt-manager \
    faenza-icon-theme papirus-icon-theme \
    ttf-anonymous-pro ttf-liberation inter-font ttf-dejavu noto-fonts noto-fonts-emoji \
    tex-gyre-fonts gnu-free-fonts xorg-fonts-misc ttf-linux-libertine ttf-opensans \
    adobe-source-serif-fonts adobe-source-sans-fonts adobe-source-code-pro-fonts

paru -S --needed \
    polybar \
    ttf-nunito montserrat-ttf otf-public-sans ttf-mac-fonts ttf-font-awesome apple-fonts

sudo systemctl enable lightdm
