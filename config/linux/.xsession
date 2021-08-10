#!/bin/sh

if [ -e "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi
if [ -e "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
fi

mkdir -p $HOME/.cache/logs
bspwm 2> $HOME/.cache/logs/bspwn.err > $HOME/.cache/logs/bspwm.log
