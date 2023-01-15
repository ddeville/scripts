set -gx FZF_TMUX 0
set -gx FZF_DEFAULT_COMMAND "fd --exclude .git --hidden --color=never"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND "fd --type d --exclude .git --hidden --color=never"
set -gx FZF_NON_COLOR_OPTS "--height 40% --border --tabstop=4"
set -gx FZF_DEFAULT_OPTS "$FZF_NON_COLOR_OPTS $FZF_BASE16_COLOR_OPS"

# alt-c doesn't work on macos so rather than tweaking the iterm settings bind it
bind -M insert ç fzf-cd-widget
