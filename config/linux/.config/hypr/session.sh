#!/bin/bash

# Each service starts independently; an optional helper must not prevent the bar.
set -u -o pipefail

dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
systemctl --user restart dunst.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service xdg-desktop-portal.service

gnome-keyring-daemon --start --components=pkcs11,secrets
if ! pgrep -u "$UID" -f '^/usr/lib/mate-polkit/polkit-mate-authentication-agent-1$' >/dev/null; then
  /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &
fi
nm-applet --indicator &
hypridle &
hyprpaper &
hyprsunset &

if command -v input-remapper-control >/dev/null; then
  input-remapper-control --command autoload
fi
if command -v 1password >/dev/null && ! pgrep -u "$UID" -x 1password >/dev/null; then
  1password &
fi
qs --no-duplicate --daemonize
