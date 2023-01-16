# This script is called whenever the base16 theme is loaded or changed.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"
read previous_theme_name <"$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"

if test "$current_theme_name" != "$previous_theme_name"
    # Let's first link the file for tmux to pick up
    set orig_path "$XDG_DATA_HOME/base16/base16-tmux/colors/base16-$current_theme_name.conf"
    set dest_path "$BASE16_CONFIG_PATH/base16-tmux.conf"

    ln -sf $orig_path $dest_path

    # And if tmux is actually running, reload it live
    if test -n "$TMUX"
        tmux source-file "$XDG_CONFIG_HOME/tmux/tmux.conf"
    end
end
