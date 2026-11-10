#!/bin/bash

set -eu -o pipefail

export LC_ALL=C

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
