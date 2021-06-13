# clean up existing path before resourcing it so that starting tmux doesn't end
# up with duplicate entries in the path (and the default paths prepended to the
# front) - this is because this config file is loaded twice when starting tmux.
if test -e "/usr/libexec/path_helper"
    set PATH ""
    eval (/usr/libexec/path_helper -c)
end

# set up a list to collect the new path entries
set -l PATH_ENTRIES

# make sure that this is before anything in the path (it overwrite others)
if test -e "$HOME/.pyenv/bin"
    if test -e "$HOME/.pyenv/shims"
        set PATH_ENTRIES $PATH_ENTRIES "$HOME/.pyenv/shims"
    end
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.pyenv/bin"
    set -x PYENV_SHELL fish
end
# add the dropbox overrides before the rest (if this is a dropbox machine)
if test -e "/opt/dropbox-override/bin"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/dropbox-override/bin"
end
# we build neovim nightly in there
if test -e "/opt/nvim/nightly_compiled"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/nvim/nightly_compiled/bin"
end
# we install neovim nightly in there
if test -e "/opt/nvim/nightly_archived"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/nvim/nightly_archived/bin"
end
# we install the lsp server binaries in there
if test -e "/opt/lsp"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/lsp"
end
# brew install its stuff there on M1 macs
if test -e "/opt/homebrew/bin"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/homebrew/bin"
end
# these can come afterwards, it's cool
if test -e "$HOME/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/bin"
end
if [ (uname -s) = "Darwin" ]; and test -e "$HOME/scripts/macos/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/scripts/macos/bin"
end
if test -e "$HOME/scripts/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/scripts/bin"
end
if test -e "$HOME/.cargo/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.cargo/bin"
end
if test -e "$HOME/.fzf/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.fzf/bin"
end
if which xcode-select > /dev/null 2>&1; and set XCODE (xcode-select --print-path); and test -e "$XCODE/usr/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$XCODE/usr/bin"
end
if test -e "/usr/local/sbin"
    set PATH_ENTRIES $PATH_ENTRIES "/usr/local/sbin"
end

# we can now set the new entries in front of the path
set -x PATH $PATH_ENTRIES $PATH

# GOPATH for Dropbox server code
if test -e "$HOME/src/server/go"
    if not set -q GOPATH || not contains "$HOME/src/server/go" "$GOPATH"
        set -x GOPATH $GOPATH "$HOME/src/server/go"
    end
end
