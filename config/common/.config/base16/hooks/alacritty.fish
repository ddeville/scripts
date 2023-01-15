# This script is called whenever the base16 theme is loaded or changed.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"

ln -sf "$XDG_DATA_HOME/base16/base16-alacritty/colors/base16-$current_theme_name-256.yml" "$BASE16_CONFIG_PATH/base16-alacritty.yml"
