#!/bin/bash
set -eu -o pipefail
umask 077
export LC_ALL=C

runtime_dir="${XDG_RUNTIME_DIR:?}/quickshell-screenshots"
wayland=false
if [ "${XDG_SESSION_TYPE:-}" = wayland ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  wayland=true
fi

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
  if "$wayland"; then
    require_command grim
    if [ "$mode" = region ]; then
      require_command slurp
      if ! geometry=$(slurp 2>"$errors"); then
        message=$(<"$errors")
        [[ -z $message || ${message,,} == *cancel* ]] && exit 2
        cat "$errors" >&2
        exit 1
      fi
      grim -g "$geometry" "$image"
    else
      grim "$image"
    fi
  else
    require_command maim
    selection=()
    [ "$mode" != region ] || selection=(--select)
    if ! maim "${selection[@]}" --hidecursor --format=png "$image" 2>"$errors"; then
      message=$(<"$errors")
      [[ ${message,,} == *cancel* ]] && exit 2
      cat "$errors" >&2
      exit 1
    fi
  fi
  [ -s "$image" ] || exit 1
  keep=true
  printf '%s\n' "$image"
  ;;
copy)
  require_capture "${2:?Missing screenshot}"
  if "$wayland"; then
    require_command wl-copy
    wl-copy --type image/png <"$2"
  else
    require_command xclip
    xclip -selection clipboard -t image/png -i "$2"
  fi
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
