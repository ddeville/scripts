# This script is called whenever the base16 theme is loaded or changed.
#
# Its goal is to update the value of the theme in
# `BASE16_SHELL_PREVIOUS_THEME_NAME_PATH` to the latest value.
#
# The goal of `BASE16_SHELL_PREVIOUS_THEME_NAME_PATH` is for hook script to
# know whether the theme has changed and whether they need to source their
# config again. For this reason it is *really* important for this script to be
# run last, hence the `x_` prefix in the name.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"
echo "$current_theme_name" >"$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"
