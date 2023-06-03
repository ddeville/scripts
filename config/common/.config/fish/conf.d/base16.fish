set -x BASE16_THEME_DEFAULT gruvbox-dark-pale

# Note that the logic below is copied from base16-shell.
#
# We do this manually here because sourcing base16-shell will walk through all
# the possible themes in order to create aliases, which is very slow.
#
# So instead we only load the current theme and offer a `base16_load_commands`
# function to actually source base16-shell, which is useful if we want to
# switch theme at runtime.

if test -f "$BASE16_SHELL_COLORSCHEME_PATH"
    sh $BASE16_SHELL_COLORSCHEME_PATH
    if test -d "$BASE16_SHELL_HOOKS_PATH"; and test (count $BASE16_SHELL_HOOKS_PATH) -eq 1
        for hook in $BASE16_SHELL_HOOKS_PATH/*.fish
            test -x "$hook"; and source "$hook"
        end
    end
else
    # If we've never set the color scheme, let's source base16-shell so that it
    # can set the default theme we've specified above.
    base16_load_commands
end
