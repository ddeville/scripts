#!/bin/bash

cw_repo_name() {
  basename "$1"
}

cw_feature_name() {
  basename "$1"
}

cw_branch_name() {
  printf 'damien/cw/%s\n' "$1"
}

cw_session_name() {
  local repo_name="$1"
  local feature_name="$2"

  printf '%s-%s\n' "$repo_name" "${feature_name//\//-}"
}

cw_main_worktree_root() {
  local repo_root="$1"
  local common_dir

  common_dir="$(git -C "$repo_root" rev-parse --path-format=absolute --git-common-dir)"
  cd "$common_dir/.." && pwd -P
}
