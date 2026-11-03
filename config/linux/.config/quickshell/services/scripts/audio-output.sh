#!/bin/bash

set -eu -o pipefail

sink=${1:?Missing output device}
port=${2:-}

if [ -n "$port" ]; then
  pactl set-sink-port "$sink" "$port"
fi
pactl set-default-sink "$sink"
