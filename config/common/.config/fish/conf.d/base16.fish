set -x BASE16_THEME_DEFAULT gruvbox-dark-pale

set -l base16_path "$XDG_DATA_HOME/base16/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    # TODO(damien): Profile what is slow to run in this script
    source $base16_path
end
