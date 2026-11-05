#!/bin/bash

set -u -o pipefail

# Publish the desktop PATH and toolkit settings before starting session services.
dbus-update-activation-environment --systemd PATH XDG_SESSION_TYPE XDG_SESSION_ID QT_QPA_PLATFORM XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE

systemctl --user start desktop-session.target
