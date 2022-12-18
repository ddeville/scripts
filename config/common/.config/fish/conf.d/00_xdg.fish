# XDG Base Directory Specification
if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME "$HOME/.config"
end
command mkdir -p $XDG_CONFIG_HOME

if not set -q XDG_CACHE_HOME
    set -gx XDG_CACHE_HOME "$HOME/.cache"
end
command mkdir -p $XDG_CACHE_HOME

if not set -q XDG_DATA_HOME
    set -gx XDG_DATA_HOME "$HOME/.local/share"
end
command mkdir -p $XDG_DATA_HOME

if not set -q XDG_STATE_HOME
    set -gx XDG_STATE_HOME "$HOME/.local/state"
end
command mkdir -p $XDG_STATE_HOME

# application specific env variables to enforce XDG

# python
set -x PYENV_ROOT "$XDG_DATA_HOME/pyenv"
set -x PYTHONSTARTUP "$XDG_CONFIG_HOME/python/startup"
# rust
set -x CARGO_HOME "$XDG_DATA_HOME/cargo"
set -x RUSTUP_HOME "$XDG_DATA_HOME/rustup"
# fzf
set -x FZF_HOME "$XDG_DATA_HOME/fzf"
# node
set -x NPM_CONFIG_USERCONFIG "$XDG_CONFIG_HOME/npm/config"
set -x NPM_CONFIG_CACHE "$XDG_CACHE_HOME/npm"
set -x NODE_REPL_HISTORY "$XDG_STATE_HOME/node/history"
command mkdir -p "$XDG_STATE_HOME/node"
# less
set -x LESSKEY "$XDG_CONFIG_HOME/less/lesskey"
set -x LESSHISTFILE "$XDG_STATE_HOME/less/history"
command mkdir -p "$XDG_STATE_HOME/less"
# bash
set -x HISTFILE "$XDG_STATE_HOME/bash/history"
command mkdir -p "$XDG_STATE_HOME/bash"
# base16
set -x BASE16_STATE_DIR "$XDG_STATE_HOME/base16"
