#!/bin/bash
set -eu -o pipefail

hyprctl -j monitors | jq -r '.[] | select(.focused) | .name'
