# use the vim key bindings
set -gx fish_key_bindings fish_vi_key_bindings

# ctrl-y to accept autocomplete suggestion
bind -M insert \cy accept-autosuggestion

# alt-c doesn't work on macos so rather than tweaking the iterm settings bind it
bind -M insert ç fzf-cd-widget
