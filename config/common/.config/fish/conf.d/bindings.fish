# use the vim key bindings
set -gx fish_key_bindings fish_vi_key_bindings

# in v4 fish correctly sets the vi insert cursor to a line but I'm too used to it being a block
set fish_cursor_insert block

# ctrl-y to accept autocomplete suggestion
bind -M insert \cy accept-autosuggestion
