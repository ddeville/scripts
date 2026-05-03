#!/bin/bash

RCODEX_REMOTE_PORT=${REMOTE_PORT:-17338}

RCODEX_REMOTE_PRELUDE=$(
  cat <<EOF
set -eu

PATH="\$HOME/.local/bin:\$HOME/bin:\$PATH"

port=$RCODEX_REMOTE_PORT

state_dir="\${XDG_STATE_HOME:-\$HOME/.local/state}/rcodex"
mkdir -p "\$state_dir"

pid_file="\$state_dir/app-server-\$port.pid"
log_file="\$state_dir/app-server-\$port.log"
EOF
)

rcodex_shell_quote() {
  local value quoted
  value=$1
  quoted=${value//\'/\'\\\'\'}
  printf "'%s'" "$quoted"
}

rcodex_format_shell_arg() {
  local arg=$1

  if [[ $arg =~ ^[A-Za-z0-9_./:=,+@%+-]+$ ]]; then
    printf '%s' "$arg"
  else
    rcodex_shell_quote "$arg"
  fi
}

rcodex_print_command_arg() {
  printf ' %s' "$(rcodex_format_shell_arg "$1")"
}

rcodex_make_control_path() {
  local state_dir

  state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/rcodex
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  printf '%s\n' "$state_dir/ssh-control.$$"
}

rcodex_start_control_master() {
  local host control_path output status

  host=$1
  control_path=$2

  set +e
  output=$(ssh \
    -MNf \
    -S "$control_path" \
    -o ClearAllForwardings=yes \
    "$host" 2>&1)
  status=$?
  set -e

  if ((status != 0)); then
    output=${output//$'\n'/ }
    echo "rcodex: failed to start ssh control master (ssh status $status)" >&2
    echo "rcodex: output: ${output:-<empty>}" >&2
    return 1
  fi
}

rcodex_stop_control_master() {
  local host control_path

  host=$1
  control_path=$2

  ssh -F none -S "$control_path" -O exit "$host" >/dev/null 2>&1 || true
}

rcodex_run_remote() {
  local action host script control_path output status
  local script_parts
  local ssh_args

  action=$1
  host=$2
  script=$3
  control_path=${4-}

  ssh_args=(ssh)
  if [[ $control_path != "" ]]; then
    ssh_args+=(-F none -S "$control_path")
  else
    ssh_args+=(-o ClearAllForwardings=yes)
  fi
  ssh_args+=("$host")

  script_parts=(
    "$RCODEX_REMOTE_PRELUDE"
    "$script"
  )
  script=$(printf '%s\n' "${script_parts[@]}")

  set +e
  # shellcheck disable=SC2029
  output=$("${ssh_args[@]}" "bash -c $(rcodex_shell_quote "$script")" 2>&1)
  status=$?
  set -e

  if ((status != 0)); then
    output=${output//$'\n'/ }
    echo "rcodex: failed to $action on $host:$RCODEX_REMOTE_PORT (ssh status $status)" >&2
    echo "rcodex: output: ${output:-<empty>}" >&2
    return 1
  fi

  if [[ ${RCODEX_PRINT_REMOTE_OUTPUT:-} != "" && -n $output ]]; then
    printf '%s\n' "$output" >&2
  fi
}
