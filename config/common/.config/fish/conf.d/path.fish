# clean up existing path before resourcing it so that starting tmux doesn't end
# up with duplicated entries in the path (and the default paths prepended to the
# front) - this is because this config file is loaded twice when starting tmux.
if test -e /usr/libexec/path_helper
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

# language toolchains
# make sure that this is before anything in the path (it overwrites others)
add_to_path "$XDG_TOOLCHAINS_HOME/python/pyenv/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/python/pyenv/shims"
add_to_path "$XDG_TOOLCHAINS_HOME/rust/cargo/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/go/current/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/go/user/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/node/current/bin"

# user binaries
add_to_path "$HOME/.local/bin"

# DEPRECATED: binaries should go in ~/.local/bin
add_to_path "$HOME/bin"

# customly built packages
add_to_path /opt/nvim/bin
add_to_path /opt/lsp/bin

# brew install its stuff there on M1 macs
add_to_path /opt/homebrew/bin
add_to_path /opt/homebrew/sbin

# brew install its stuff there on linux
# note that we support filtering only the leaf packages so prefer that if we've opted in
if test -e /home/linuxbrew/.filtered
    add_to_path /home/linuxbrew/.filtered/bin
    add_to_path /home/linuxbrew/.filtered/sbin
else
    add_to_path /home/linuxbrew/.linuxbrew/bin
    add_to_path /home/linuxbrew/.linuxbrew/sbin
end

# check whether xcode is installed and add its bin dir to the path if so
if which xcode-select >/dev/null 2>&1; and set -l XC (xcode-select --print-path)
    add_to_path "$XC/usr/bin"
end

# we can now set the new entries in front of the path
set -x PATH $PATH_ENTRIES $PATH
set -e PATH_ENTRIES
functions -e add_to_path
