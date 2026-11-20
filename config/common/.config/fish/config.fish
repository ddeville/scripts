set -gx CLICOLOR 1
set -gx EDITOR nvim
set -gx NAME "Damien Deville"
set -gx EMAIL damien@ddeville.me
set -gx TZ America/Los_Angeles

# Give each pane its own OpenSSH agent link so panes stay independent when a window moves.
if status is-interactive; and set -q TMUX TMUX_PANE
    set -gx TMUX_SSH_AUTH_SOCK "$TMUX.$TMUX_PANE.agent"
end

# Sometimes this is not set correctly if only the Xcode CLI tools are installed
if test (uname) = Darwin && ! test -n "$SDKROOT"
    set -gx SDKROOT (xcrun --sdk macosx --show-sdk-path)
end
