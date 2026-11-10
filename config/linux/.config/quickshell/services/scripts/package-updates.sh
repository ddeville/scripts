#!/bin/bash

set -eu -o pipefail
export LC_ALL=C

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
