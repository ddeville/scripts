#!/bin/sh

if [ -f /etc/X11/xinit/.Xresources ]; then
  xrdb -merge /etc/X11/xinit/.Xresources
fi
if [ -e "$HOME/.Xresources" ]; then
  xrdb -merge "$HOME/.Xresources"
fi

if [ -f /etc/X11/xinit/.Xmodmap ]; then
  xmodmap /etc/X11/xinit/.Xmodmap
fi
if [ -e "$HOME/.Xmodmap" ]; then
  xmodmap "$HOME/.Xmodmap"
fi

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
  for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

dbus-update-activation-environment --systemd DISPLAY
gpgconf --launch gpg-agent
export "SSH_AUTH_SOCK=/run/user/$(id -u)/gnupg/S.gpg-agent.ssh"

mkdir -p $HOME/.cache/logs

xsetroot -cursor_name left_ptr
bspwm 2> $HOME/.cache/logs/bspwn.err > $HOME/.cache/logs/bspwm.log
