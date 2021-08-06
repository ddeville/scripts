#!/bin/sh

if [ -f /etc/X11/xinit/.Xresources ]; then
  xrdb -merge /etc/X11/xinit/.Xresources
fi

if [ -f /etc/X11/xinit/.Xmodmap ]; then
  xmodmap /etc/X11/xinit/.Xmodmap
fi

if [ -f "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi

if [ -f "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
fi

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
  for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

xsetroot -cursor_name left_ptr
nitrogen --restore &
exec bspwm
