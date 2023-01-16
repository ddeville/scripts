# This script is called whenever the base16 theme is loaded or changed.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"
read previous_theme_name <"$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"

if test "$current_theme_name" = "$previous_theme_name"
    return
end

set nvim_path "$BASE16_CONFIG_PATH/set_theme.lua"
set nvim_output (string join "\n" \
  "local current_theme_name = \"$current_theme_name\"" \
  "if current_theme_name ~= \"\" and vim.g.colors_name ~= 'base16-' .. current_theme_name then" \
  "  vim.cmd('colorscheme base16-' .. current_theme_name)" \
  "end")
echo -e "$nvim_output" >"$nvim_path"
