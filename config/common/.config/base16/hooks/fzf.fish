# This script is called whenever the base16 theme is loaded or changed.

read current_theme_name <"$BASE16_SHELL_THEME_NAME_PATH"
read previous_theme_name <"$BASE16_SHELL_PREVIOUS_THEME_NAME_PATH"

if test "$current_theme_name" = "$previous_theme_name"
    return
end

# NOTE: base16-fzf edits and exports `FZF_DEFAULT_OPTS` to a universal
# variable, which is not a behavior we want here.
# So instead we set a new `FZF_BASE16_COLOR_OPS` (and make sure that it only
# contains the color info) and we use it in Fish to populate `FZF_DEFAULT_OPTS`.

# Delete `FZF_DEFAULT_OPTS` so that sourcing the script doesn't pick it up.
# Note that we will source `fzf.fish` again which will reconstruct it.
set --global --erase FZF_DEFAULT_OPTS
source "$XDG_DATA_HOME/base16/base16-fzf/fish/base16-$current_theme_name.fish"

# We can now retrieve `FZF_DEFAULT_OPTS` (that will only contain the color
# info), populate `FZF_BASE16_COLOR_OPS` and clear the universal variable.
set --global --export FZF_BASE16_COLOR_OPS "$FZF_DEFAULT_OPTS"
set --universal --erase FZF_DEFAULT_OPTS

# Source the `fzf.fish` again to pick up the new colors.
source "$XDG_CONFIG_HOME/fish/conf.d/fzf.fish"
