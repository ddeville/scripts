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

set -gx EDITOR nvim
set -gx CLICOLOR 1
set -gx GREP_OPTIONS "--color=auto"
set -gx VIMINIT "source ~/.vim/vimrc"
set -gx MYVIMRC "$XDG_CONFIG_HOME/nvim/init.vim"
set -gx PYENV_SHELL fish

set -l base16_path "$XDG_CONFIG_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end
