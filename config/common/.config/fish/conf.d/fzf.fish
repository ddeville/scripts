set -x FZF_TMUX 0
set -x FZF_DEFAULT_OPTS "--height 40% --border --tabstop=4"
set -x FZF_DEFAULT_COMMAND "fd --exclude .git --hidden --color=never"
set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -x FZF_ALT_C_COMMAND "fd --type d --exclude .git --hidden --color=never"

# alt-c doesn't work on macos so rather than tweaking the iterm settings bind it
bind -M insert ç fzf-cd-widget
