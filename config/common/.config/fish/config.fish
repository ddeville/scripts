set -gx CLICOLOR 1
set -gx EDITOR nvim
set -gx PYENV_SHELL fish

# Base16
set -l base16_path "$XDG_DATA_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end
set -x BASE16_THEME_DEFAULT base16-gruvbox-dark-pale

# Golang
set -x GOPATH "$HOME/src/go"

# setup `fzf`
set -x FZF_TMUX 0
set -x FZF_DEFAULT_OPTS "--height 40% --border --tabstop=4"
set -x FZF_DEFAULT_COMMAND "fd --exclude .git --hidden --color=never"
set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -x FZF_ALT_C_COMMAND "fd --type d --exclude .git --hidden --color=never"

# Sometimes this is not set correctly if only the Xcode CLI tools are installed
if test (uname) = Darwin && ! test -n "$SDKROOT"
    set -gx SDKROOT (xcrun --sdk macosx --show-sdk-path)
end

# 1Password command-line plugins
if test -e "$XDG_CONFIG_HOME/op/plugins.sh"
    source "$XDG_CONFIG_HOME/op/plugins.sh"
end
