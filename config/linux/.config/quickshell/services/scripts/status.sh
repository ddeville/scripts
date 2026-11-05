#!/bin/bash

set -eu -o pipefail
export LC_ALL=C

case "${1:-}" in
stats)
  cpu=$(awk '/^cpu / {total=0; for(i=2;i<=9;i++) total+=$i; printf "%.0f %.0f\n", total, $5+$6; exit}' /proc/stat)
  memory=$(awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {available=$2} END {printf "%.0f", 100*(total-available)/total}' /proc/meminfo)
  temperature=null
  for sensor in /sys/class/hwmon/hwmon*/temp*_label; do
    [ -r "$sensor" ] || continue
    if [ "$(<"$sensor")" = Tctl ] || [ "$(<"$sensor")" = 'Package id 0' ]; then
      temperature=$(awk '{printf "%.0f", $1/1000*9/5+32}' "${sensor%_label}_input")
      break
    fi
  done
  backlight=null
  for device in /sys/class/backlight/*; do
    [ -r "$device/brightness" ] || continue
    backlight=$((100 * $(<"$device/brightness") / $(<"$device/max_brightness")))
    break
  done
  battery=null
  battery_status=""
  plugged=false
  for device in /sys/class/power_supply/*; do
    if [ -r "$device/online" ] && [ "$(<"$device/online")" = 1 ]; then
      plugged=true
      break
    fi
  done
  for device in /sys/class/power_supply/*; do
    [ -r "$device/type" ] && [ "$(<"$device/type")" = Battery ] || continue
    [ -r "$device/capacity" ] || continue
    battery=$(<"$device/capacity")
    battery_status=$(<"$device/status")
    break
  done
  network='{}'
  for device in /sys/class/net/*; do
    # Count physical links once, excluding VPNs and virtual bridges.
    [ -e "$device/device" ] || continue
    [ "$(<"$device/operstate")" = up ] || continue
    network=$(jq -c --arg interface "${device##*/}" \
      --argjson rx "$(<"$device/statistics/rx_bytes")" --argjson tx "$(<"$device/statistics/tx_bytes")" \
      '. + {($interface): [$rx, $tx]}' <<<"$network")
  done
  read -r uptime _ </proc/uptime
  jq -cn --arg cpu "$cpu" --argjson memory "$memory" --argjson temperature "$temperature" \
    --argjson backlight "$backlight" --argjson battery "$battery" --arg batteryStatus "$battery_status" --argjson plugged "$plugged" \
    --argjson network "$network" --argjson uptime "$uptime" \
    '{cpu: ($cpu | split(" ") | map(tonumber)), memory: $memory, temperature: $temperature,
        backlight: $backlight, battery: $battery, batteryStatus: $batteryStatus, plugged: $plugged,
        network: $network, uptime: $uptime}'
  ;;
updates)
  # checkupdates uses exit code 2 for an empty update list.
  if official=$(timeout 90 checkupdates 2>/dev/null); then
    :
  elif [ "$?" -eq 2 ]; then
    official=""
  else
    echo unavailable
    exit 0
  fi
  aur_errors=$(mktemp)
  trap 'rm -f "$aur_errors"' EXIT
  # paru returns 1 with no output when there are no AUR updates.
  if aur=$(timeout 90 paru -Qua 2>"$aur_errors"); then
    :
  elif [ "$?" -eq 1 ] && [ -z "$aur" ] && [ ! -s "$aur_errors" ]; then
    aur=""
  else
    echo unavailable
    exit 0
  fi
  printf '%s\n%s\n' "$official" "$aur" | awk 'NF {n++} END {print n+0}'
  ;;
email)
  token_file="${XDG_CONFIG_HOME:-$HOME/.config}/fastmail/email.token"
  [ -s "$token_file" ] || exit 0
  if count=$(timeout 20 "$HOME/.local/bin/fastmail-check-unread" "$(<"$token_file")" 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
    echo "$count"
  else
    echo offline
  fi
  ;;
github)
  token_file="${XDG_CONFIG_HOME:-$HOME/.config}/github/notifications.token"
  [ -s "$token_file" ] || exit 0
  # Pass the header on stdin so the token does not appear in curl's arguments.
  if response=$(printf 'Authorization: Bearer %s\n' "$(<"$token_file")" |
    curl --fail --silent --max-time 15 --header @- 'https://api.github.com/notifications?per_page=100'); then
    jq -er 'if type == "array" then (length | tostring) + (if length == 100 then "+" else "" end) else error("invalid response") end' <<<"$response" 2>/dev/null || echo offline
  else
    echo offline
  fi
  ;;
*)
  echo "Usage: $0 {stats|updates|email|github}" >&2
  exit 1
  ;;
esac
