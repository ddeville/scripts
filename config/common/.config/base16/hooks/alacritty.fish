# This script is called whenever the base16 theme is loaded or changed.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"
if test -e "$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"
    read previous_theme_name <"$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"
end

if test "$current_theme_name" != "$previous_theme_name"
    ln -sf "$XDG_DATA_HOME/base16/base16-alacritty/colors/base16-$current_theme_name-256.toml" "$BASE16_CONFIG_PATH/base16-alacritty.toml"
end
