#!/bin/bash
set -eu -o pipefail
umask 077
export LC_ALL=C

runtime_dir="${XDG_RUNTIME_DIR:?}/quickshell-screenshots"

require_command() {
  command -v "$1" >/dev/null || {
    echo "Screenshots require $1 to be installed." >&2
    exit 1
  }
}

require_capture() {
  [[ ${1%/*} == "$runtime_dir" && ${1##*/} == capture-*.png && -f $1 ]] || {
    echo "The screenshot is no longer available." >&2
    exit 1
  }
}

case "${1:-}" in
capture)
  mode=${2:?Missing capture mode}
  [[ $mode == full || $mode == region ]] || exit 1
  mkdir -p "$runtime_dir"
  image=$(mktemp "$runtime_dir/capture-XXXXXX.png")
  errors=$(mktemp "$runtime_dir/errors-XXXXXX")
  keep=false
  trap 'rm -f -- "$errors"; if ! "$keep"; then rm -f -- "$image"; fi' EXIT
  require_command grim
  if [ "$mode" = region ]; then
    require_command slurp
    if ! geometry=$(slurp </dev/null 2>"$errors"); then
      message=$(<"$errors")
      [[ -z $message || ${message,,} == *cancel* ]] && exit 2
      cat "$errors" >&2
      exit 1
    fi
    grim -g "$geometry" "$image"
  else
    grim "$image"
  fi
  [ -s "$image" ] || exit 1
  keep=true
  printf '%s\n' "$image"
  ;;
copy)
  require_capture "${2:?Missing screenshot}"
  require_command wl-copy
  # Keep the clipboard owner alive across Quickshell service restarts.
  systemd-run --user --scope --collect --quiet --slice=app.slice \
    --property=PartOf=graphical-session.target -- wl-copy --type image/png <"$2"
  ;;
save)
  require_capture "${2:?Missing screenshot}"
  directory=${3:?Missing destination directory}
  mkdir -p "$directory"
  destination=$(mktemp "$directory/screenshot-$(date +%Y_%m_%d-%H_%M_%S)-XXXXXX.png")
  if ! cp -- "$2" "$destination"; then
    rm -f -- "$destination"
    exit 1
  fi
  printf '%s\n' "$destination"
  ;;
discard)
  require_capture "${2:?Missing screenshot}"
  rm -f -- "$2"
  ;;
*)
  echo "Usage: $0 {capture full|capture region|copy FILE|save FILE DIRECTORY|discard FILE}" >&2
  exit 1
  ;;
esac
