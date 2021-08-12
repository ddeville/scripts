#!/bin/sh

# This file is only needed when calling `startx` directly from a TTY.
# It is not sourced by LightDM that loads `.xprofile` directly instead.

[ -e "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
[ -e "$HOME/.Xmodmap" ] && xmodmap "$HOME/.Xmodmap"
[ -e /etc/xprofile ] && . /etc/xprofile
[ -e "$HOME/.xprofile" ] && . "$HOME/.xprofile"

exec bspwm
