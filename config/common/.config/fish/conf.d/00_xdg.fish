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
set -x BASE16_CONFIG_PATH "$XDG_STATE_HOME/base16"
set -x BASE16_SHELL_PATH "$XDG_DATA_HOME/base16/base16-shell"
set -x BASE16_SHELL_HOOKS_PATH "$XDG_CONFIG_HOME/base16/hooks"
set -x BASE16_SHELL_PREVIOUS_THEME_NAME_PATH "$BASE16_CONFIG_PATH/theme_name_previous"

# ripgrep
set -x RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# tmux
set -x TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"

# golang
set -x GOPATH "$HOME/src/go"
