# clean up existing path before resourcing it so that starting tmux doesn't end
# up with duplicated entries in the path (and the default paths prepended to the
# front) - this is because this config file is loaded twice when starting tmux.
if test -e "/usr/libexec/path_helper"
    set PATH ""
    eval (/usr/libexec/path_helper -c)
end

# set up a list to collect the new path entries
set PATH_ENTRIES

function add_to_path
    set -l p $argv[1]
    if test -e $p; and not contains $p $PATH_ENTRIES
        set PATH_ENTRIES $PATH_ENTRIES $p
    end
end

# make sure that this is before anything in the path (it overwrite others)
add_to_path "$HOME/.pyenv/bin"
add_to_path "$HOME/.pyenv/shims"

# add the dropbox overrides before the rest (if this is a dropbox machine)
add_to_path "/opt/dropbox-override/bin"

# we build and archive neovim nightly in there (prefer compiled over archived)
add_to_path "/opt/nvim/nightly_compiled/bin"
add_to_path "/opt/nvim/nightly_archived/bin"

# we install the lsp server binaries in there
add_to_path "/opt/lsp"

# brew install its stuff there on M1 macs
add_to_path "/opt/homebrew/bin"

# these can come afterwards, it's cool
add_to_path "$HOME/bin"

if [ (uname -s) = "Darwin" ]
    add_to_path "$HOME/scripts/macos/bin"
end

add_to_path "$HOME/scripts/bin"
add_to_path "$HOME/.cargo/bin"
add_to_path "$HOME/.fzf/bin"

# check whether xcode is installed and add its bin dir to the path if so
if which xcode-select > /dev/null 2>&1; and set -l XC (xcode-select --print-path)
    add_to_path "$XC/usr/bin"
end

add_to_path "/usr/local/sbin"

# we can now set the new entries in front of the path
set -x PATH $PATH_ENTRIES $PATH
set -e PATH_ENTRIES

# GOPATH for Dropbox server code
if test -e "$HOME/src/server/go"
    if not set -q GOPATH || not contains "$HOME/src/server/go" "$GOPATH"
        set -x GOPATH $GOPATH "$HOME/src/server/go"
    end
end
