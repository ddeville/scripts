#!/bin/bash

# shellcheck disable=SC2034

PYTHON_TOOLCHAIN_GLOBAL_DIR="$XDG_TOOLCHAINS_HOME/python/global"
PYTHON_TOOLCHAIN_GLOBAL_VENV="$VENV_INSTALL_DIR/global"
PYTHON_TOOLCHAIN_REQUIREMENTS_FILE="$PYTHON_TOOLCHAIN_GLOBAL_DIR/requirements.txt"

python_toolchain_sync_global_venv() {
  local python_request="$1"
  local venv_flag="$2"

  mkdir -p "$PYTHON_TOOLCHAIN_GLOBAL_DIR"
  touch "$PYTHON_TOOLCHAIN_REQUIREMENTS_FILE"

  env -u VIRTUAL_ENV uv venv "$venv_flag" --python "$python_request" "$PYTHON_TOOLCHAIN_GLOBAL_VENV"

  env -u VIRTUAL_ENV uv pip install \
    --upgrade \
    --refresh \
    --exclude-newer 3d \
    --python "$PYTHON_TOOLCHAIN_GLOBAL_VENV/bin/python" \
    --requirements "$PYTHON_TOOLCHAIN_REQUIREMENTS_FILE"
}
