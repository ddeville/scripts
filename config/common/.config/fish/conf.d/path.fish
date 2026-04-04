# clean up PATH before resourcing it so that starting tmux doesn't end up with
# duplicated entries.
# on macOS, reset the default PATH from path_helper first.
if test -e /usr/libexec/path_helper
    set PATH
    eval (/usr/libexec/path_helper -c)
end

# de-duplicate the inherited/default PATH before prepending custom entries.
set CLEAN_PATH
for p in $PATH
    if not contains -- $p $CLEAN_PATH
        set CLEAN_PATH $CLEAN_PATH $p
    end
end

# set up a list to collect the new path entries.
set PATH_ENTRIES

function add_to_path
    set -l p $argv[1]
    if test -e $p; and not contains -- $p $PATH_ENTRIES
        set PATH_ENTRIES $PATH_ENTRIES $p
    end
end

# language toolchains
# make sure that this is before anything in the path (it overwrites others)
add_to_path "$XDG_TOOLCHAINS_HOME/rust/cargo/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/python/uv/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/go/current/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/go/user/bin"
add_to_path "$XDG_TOOLCHAINS_HOME/node/current/bin"

# user binaries
add_to_path "$HOME/.local/bin"

# DEPRECATED: binaries should go in ~/.local/bin
add_to_path "$HOME/bin"

# customly built packages
add_to_path /opt/nvim/bin

# brew install its stuff there on M1 macs
add_to_path /opt/homebrew/bin
add_to_path /opt/homebrew/sbin

# brew installs its stuff there on Linux
add_to_path /home/linuxbrew/.linuxbrew/bin
add_to_path /home/linuxbrew/.linuxbrew/sbin

# check whether xcode is installed and add its bin dir to the path if so
if which xcode-select >/dev/null 2>&1; and set -l XC (xcode-select --print-path)
    add_to_path "$XC/usr/bin"
end

# we can now set the new entries in front of the path without introducing
# duplicates if this file is sourced more than once.
set FINAL_PATH $PATH_ENTRIES
for p in $CLEAN_PATH
    if not contains -- $p $FINAL_PATH
        set FINAL_PATH $FINAL_PATH $p
    end
end

set -x PATH $FINAL_PATH

set -e CLEAN_PATH
set -e FINAL_PATH
set -e PATH_ENTRIES
functions -e add_to_path
