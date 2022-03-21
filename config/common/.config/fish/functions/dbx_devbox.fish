function dbx_devbox --description "SSH to my devbox"
    ssh -o ServerAliveInterval=180 -o ServerAliveCountMax=2 -A -J \
        damien@damien-mp.home.kattungar.net \
        damien-dbx -t "
        if not tmux list-sessions 2> /dev/null | grep devbox > /dev/null 2>&1
            tmux new-session -D -s devbox -d -c ~
            tmux new-window -t devbox -n repo -d -c ~/src/server-mirror
            tmux new-window -t devbox -n editor -d -c ~/src/server-mirror
            tmux send-keys -t devbox:3 \"nvim .\" Enter
            tmux new-window -t devbox -n scripts -d -c ~/scripts
            tmux kill-window -t devbox:1
            tmux move-window -s devbox:2 -t devbox:1
            tmux move-window -s devbox:3 -t devbox:2
            tmux move-window -s devbox:4 -t devbox:3
            tmux select-window -t devbox:1
        end
        command tmux attach -d -t devbox
        "
end
