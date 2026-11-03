#!/bin/bash
set -eu -o pipefail

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  hyprctl -j monitors | jq -r '.[] | select(.focused) | .name'
else
  bspc query -M -m focused --names
fi
