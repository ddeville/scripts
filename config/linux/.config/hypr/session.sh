#!/bin/bash

set -u -o pipefail

# Hyprland imports display variables; also pass our session and toolkit settings to services.
systemctl --user import-environment XDG_SESSION_TYPE XDG_SESSION_ID QT_QPA_PLATFORM XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE

# Start only for this session; the units stop with graphical-session.target.
systemctl --user start \
  hypridle.service \
  hyprpaper.service \
  hyprsunset.service \
  quickshell.service \
  nm-applet.service \
  polkit-mate.service

if command -v input-remapper-control >/dev/null; then
  input-remapper-control --command autoload
fi
