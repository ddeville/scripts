#!/bin/bash

RCODEX_REMOTE_PORT=${REMOTE_PORT:-17338}

rcodex_shell_quote() {
  local value quoted
  value=$1
  quoted=${value//\'/\'\\\'\'}
  printf "'%s'" "$quoted"
}

rcodex_remote_common_script() {
  cat <<EOF
set -eu

PATH="\$HOME/.local/bin:\$HOME/bin:\$PATH"

port=$RCODEX_REMOTE_PORT
state_dir="\${XDG_STATE_HOME:-\$HOME/.local/state}/rcodex"
pid_file="\$state_dir/app-server-\$port.pid"
log_file="\$state_dir/app-server-\$port.log"
EOF
}

rcodex_run_remote() {
  local command_name action host script print_success_output output status
  command_name=$1
  action=$2
  host=$3
  script=$4
  print_success_output=${5-}

  set +e
  # shellcheck disable=SC2029
  output=$(ssh "$host" "bash -c $(rcodex_shell_quote "$script")" 2>&1)
  status=$?
  set -e

  if ((status != 0)); then
    output=${output//$'\n'/ }
    echo "$command_name: failed to $action on $host:$RCODEX_REMOTE_PORT (ssh status $status)" >&2
    echo "$command_name: output: ${output:-<empty>}" >&2
    return 1
  fi

  if [[ $print_success_output == "print" && -n $output ]]; then
    printf '%s\n' "$output" >&2
  fi
}
