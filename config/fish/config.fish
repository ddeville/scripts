set -gx EDITOR nvim
set -gx CLICOLOR 1
set -gx GREP_OPTIONS "--color=auto"
set -gx VIMINIT "source ~/.vim/vimrc"

# XDG Base Directory
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_DATA_HOME "$HOME/.local/share"

# use the vim key bindings
set -gx fish_key_bindings fish_vi_key_bindings

set -gx fish_greeting "
     /\     /\\
    {  `---'  }
    {  O   O  }
    ~~>  V  <~~
     \  \|/  /
      `-----'____
      /     \    \_
     {       }\  )_\_   _
     |  \_/  |/ /  \_\_/ )
      \__/  /(_/     \__/
        (__/

     Did I hear fish? Meow!
"

source "$XDG_CONFIG_HOME/fish/config/colors.fish"
source "$XDG_CONFIG_HOME/fish/config/path.fish"
source "$XDG_CONFIG_HOME/fish/config/alias.fish"

# ctrl-y to accept autocomplete suggestion
bind -M insert \cy accept-autosuggestion

# setup `fzf`
set -x FZF_TMUX 0
set -x FZF_DEFAULT_OPTS "--height 40% --border --tabstop=4"
set -x FZF_DEFAULT_COMMAND "fd --exclude .git --hidden --color=never"
set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -x FZF_ALT_C_COMMAND "fd --type d --exclude .git --hidden --color=never"
# alt-c doesn't work on macos so rather than tweaking the iterm settings bind it
bind -M insert "ç" fzf-cd-widget
