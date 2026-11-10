#!/bin/bash

set -eu -o pipefail
export LC_ALL=C

token_file="${XDG_CONFIG_HOME:-$HOME/.config}/github/notifications.token"
[ -s "$token_file" ] || exit 0
# Pass the header on stdin so the token does not appear in curl's arguments.
if response=$(printf 'Authorization: Bearer %s\n' "$(<"$token_file")" |
  curl --fail --silent --max-time 15 --header @- 'https://api.github.com/notifications?per_page=100'); then
  jq -er 'if type == "array" then (length | tostring) + (if length == 100 then "+" else "" end) else error("invalid response") end' <<<"$response" 2>/dev/null || echo offline
else
  echo offline
fi
