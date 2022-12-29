set -gx CLICOLOR 1
set -gx EDITOR nvim
set -gx PYENV_SHELL fish

# We need this to be set for git
set -gx TERM xterm-256color

set -l base16_path "$XDG_DATA_HOME/base16-shell/profile_helper.fish"
if status --is-interactive && test -e $base16_path
    source $base16_path
end

set -x GOPATH "$HOME/src/go"

# Sometimes this is not set correctly if only the Xcode CLI tools are installed
if test (uname) = "Darwin" && ! test -n "$SDKROOT"
    set -gx SDKROOT (xcrun --sdk macosx --show-sdk-path)
end
