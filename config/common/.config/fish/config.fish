set -gx CLICOLOR 1
set -gx TERM xterm-256color
set -gx EDITOR nvim
set -gx PYENV_SHELL fish

set -l base16_path "$XDG_DATA_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end

set -x GOPATH "$HOME/src/go"
if test -e "$HOME/src/server/go"
    # For Dropbox server code
    set -x GOPATH $GOPATH "$HOME/src/server/go"
end
