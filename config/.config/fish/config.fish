set -gx EDITOR nvim
set -gx CLICOLOR 1
set -gx PYENV_SHELL fish

set -l base16_path "$XDG_DATA_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end
