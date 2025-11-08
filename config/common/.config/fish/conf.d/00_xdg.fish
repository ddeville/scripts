# XDG Base Directory Specification

if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME "$HOME/.config"
end
if not test -d "$XDG_CONFIG_HOME"
    command mkdir -p "$XDG_CONFIG_HOME"
end

if not set -q XDG_CACHE_HOME
    set -gx XDG_CACHE_HOME "$HOME/.cache"
end
if not test -d "$XDG_CACHE_HOME"
    command mkdir -p "$XDG_CACHE_HOME"
end

if not set -q XDG_DATA_HOME
    set -gx XDG_DATA_HOME "$HOME/.local/share"
end
if not test -d "$XDG_DATA_HOME"
    command mkdir -p "$XDG_DATA_HOME"
end

if not set -q XDG_STATE_HOME
    set -gx XDG_STATE_HOME "$HOME/.local/state"
end
if not test -d "$XDG_STATE_HOME"
    command mkdir -p "$XDG_STATE_HOME"
end

############################
######## Toolchains ########
############################

set -gx XDG_TOOLCHAINS_HOME "$HOME/.local/toolchains"
if not test -d "$XDG_TOOLCHAINS_HOME"
    command mkdir -p "$XDG_TOOLCHAINS_HOME"
end

# python
set -x UV_PYTHON_INSTALL_DIR "$XDG_TOOLCHAINS_HOME/python/uv/python"
set -x UV_PYTHON_BIN_DIR "$XDG_TOOLCHAINS_HOME/python/uv/bin"
set -x VENV_INSTALL_DIR "$XDG_TOOLCHAINS_HOME/python/venv"
if not test -d "$UV_PYTHON_BIN_DIR"
    command mkdir -p "$UV_PYTHON_BIN_DIR"
end

# rust
set -x CARGO_HOME "$XDG_TOOLCHAINS_HOME/rust/cargo"
set -x RUSTUP_HOME "$XDG_TOOLCHAINS_HOME/rust/rustup"
if not test -d "$CARGO_HOME"
    command mkdir -p "$CARGO_HOME"
end

# golang
set -x GOPATH "$XDG_TOOLCHAINS_HOME/go/user"
set -x GOBIN "$XDG_TOOLCHAINS_HOME/go/user/bin"
if not test -d "$GOBIN"
    command mkdir -p "$GOBIN"
end

# node
# NOTE: we already add custom node toolchain to the path and `npm install` will auto-discover the node_modules...

# terraform
# NOTE: the only way to change tfswitch directories it via arguments, see `tfswitch.fish` function that does that...

############################
####### Applications #######
############################

# readline
set -x INPUTRC "$XDG_CONFIG_HOME/readline/inputrc"

# python (3.13+ supports PYTHON_HISTORY, older ones still need PYTHONSTARTUP)
set -x PYTHON_HISTORY "$XDG_STATE_HOME/python/history"
set -x PYTHONSTARTUP "$XDG_CONFIG_HOME/python/startup"

# sqlite
set -x SQLITE_HISTORY "$XDG_STATE_HOME/sqlite3/history"

# node
set -x NPM_CONFIG_PREFIX "$HOME/.local"
set -x NPM_CONFIG_USERCONFIG "$XDG_CONFIG_HOME/npm/config"
set -x NPM_CONFIG_CACHE "$XDG_CACHE_HOME/npm"
set -x NODE_REPL_HISTORY "$XDG_STATE_HOME/node/history"
if not test -d "$XDG_STATE_HOME/node"
    command mkdir -p "$XDG_STATE_HOME/node"
end

# less
set -x LESSKEY "$XDG_CONFIG_HOME/less/lesskey"
set -x LESSHISTFILE "$XDG_STATE_HOME/less/history"
if not test -d "$XDG_STATE_HOME/less"
    command mkdir -p "$XDG_STATE_HOME/less"
end

# bash
set -x HISTFILE "$XDG_STATE_HOME/bash/history"
if not test -d "$XDG_STATE_HOME/bash"
    command mkdir -p "$XDG_STATE_HOME/bash"
end

# base16
set -x BASE16_CONFIG_PATH "$XDG_STATE_HOME/base16"
set -x BASE16_SHELL_PATH "$XDG_DATA_HOME/base16/base16-shell"
set -x BASE16_SHELL_HOOKS_PATH "$XDG_CONFIG_HOME/base16/hooks"
set -x BASE16_SHELL_COLORSCHEME_PATH "$BASE16_CONFIG_PATH/base16_shell_theme"
set -x BASE16_SHELL_THEME_NAME_PATH "$BASE16_CONFIG_PATH/theme_name"
set -x BASE16_SHELL_PREVIOUS_THEME_NAME_PATH "$BASE16_CONFIG_PATH/theme_name_previous"

# ripgrep
set -x RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# tmux
set -x TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"
