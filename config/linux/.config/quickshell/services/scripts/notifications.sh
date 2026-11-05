#!/bin/bash

set -eu -o pipefail

state_file="${XDG_RUNTIME_DIR:?}/quickshell-notifications-until"
unit=quickshell-notifications-resume

# Serialize polling and user actions while replacing the scheduled resume.
exec 9>"$state_file.lock"
flock 9

cancel_timer() {
  systemctl --user stop "$unit.timer" "$unit.service" 2>/dev/null || true
  rm -f "$state_file"
}

case "${1:-}" in
status)
  paused=$(dunstctl is-paused)
  until=0
  if [ -f "$state_file" ]; then
    if [ "$paused" = true ]; then
      until=$(<"$state_file")
    else
      cancel_timer
    fi
  fi
  jq -cn --argjson paused "$paused" --argjson until "$until" '{paused: $paused, until: $until}'
  ;;
pause)
  seconds=${2:-0}
  [[ $seconds =~ ^[0-9]+$ ]] || exit 2
  cancel_timer
  dunstctl set-paused true
  if [ "$seconds" -gt 0 ]; then
    until=$(($(date +%s) + seconds))
    if ! systemd-run --user --quiet --collect --unit="$unit" \
      --property=PartOf=graphical-session.target \
      --timer-property=PartOf=graphical-session.target \
      --on-calendar="@$until" --timer-property=AccuracySec=1s \
      /usr/bin/dunstctl set-paused false; then
      dunstctl set-paused false
      echo "Could not schedule resume; notifications are still enabled." >&2
      exit 1
    fi
    printf '%s\n' "$until" >"$state_file"
  fi
  ;;
resume)
  dunstctl set-paused false
  cancel_timer
  ;;
*)
  echo "Usage: $0 {status|pause [seconds]|resume}" >&2
  exit 2
  ;;
esac
