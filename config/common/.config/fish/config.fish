set -gx CLICOLOR 1
set -gx EDITOR nvim
set -gx PYENV_SHELL fish

# We need this to be set for git
if test -n "$TMUX"
    set -gx TERM tmux-256color
else
    set -gx TERM xterm-256color
end

set -l base16_path "$XDG_DATA_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end

set -x GOPATH "$HOME/src/go"
if test -e "$HOME/src/server/go"
    # For Dropbox server code
    set -x GOPATH $GOPATH "$HOME/src/server/go"
end
