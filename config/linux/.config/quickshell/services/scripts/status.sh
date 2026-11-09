#!/bin/bash

set -eu -o pipefail
export LC_ALL=C

case "${1:-}" in
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
  token=$(<"$token_file")
  if ! account_id=$(printf 'Authorization: Bearer %s\n' "$token" |
    curl --fail --silent --location --max-time 10 --header @- 'https://api.fastmail.com/.well-known/jmap' |
    jq -er '.primaryAccounts."urn:ietf:params:jmap:mail"' 2>/dev/null); then
    echo offline
    exit 0
  fi
  query=$(jq -cn --arg account_id "$account_id" '{
    using: ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
    methodCalls: [
      ["Mailbox/query", {accountId: $account_id, filter: {role: "inbox"}}, "inbox_query"],
      ["Mailbox/get", {accountId: $account_id, "#ids": {resultOf: "inbox_query", name: "Mailbox/query", path: "/ids/*"}}, "0"]
    ]
  }')
  if count=$(printf 'Authorization: Bearer %s\n' "$token" |
    curl --fail --silent --location --max-time 10 --header @- --header 'Content-Type: application/json' \
      --data "$query" 'https://api.fastmail.com/jmap/api/' |
    jq -r '.methodResponses[1][1].list[0].unreadEmails' 2>/dev/null) && [[ $count =~ ^[0-9]+$ ]]; then
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
  echo "Usage: $0 {updates|email|github}" >&2
  exit 1
  ;;
esac
