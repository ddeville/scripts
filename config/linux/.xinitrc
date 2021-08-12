#!/bin/sh

# This file is only needed when calling `startx` directly from a TTY.
# It is not sourced by LightDM that loads `.xprofile` directly instead.

if [ -e "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi
if [ -e "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
fi

# Load `.xprofile` manually
[ -f /etc/xprofile ] && . /etc/xprofile
[ -f ~/.xprofile ] && . ~/.xprofile

exec bspwm
