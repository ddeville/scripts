function dbx_tmux
    set session "dbx"
    if not command tmux list-sessions | grep $session > /dev/null 2>&1
        # repo
        command tmux new-session -D -s $session -d -n "repo" -c ~/src/client

        # editor
        command tmux new-window -t $session -n "editor" -d -c ~/src/client
        command tmux send-keys -t $session:2 "nvim ." Enter

        # server
        command tmux new-window -t $session -n "server" -d -c ~/src/server

        # server-ed
        command tmux new-window -t $session -n "server-ed" -d -c ~/src/server
        command tmux send-keys -t $session:4 "nvim ." Enter

        # vpn
        command tmux new-window -t $session -n "vpn" -d -c ~
    end
    command tmux attach -d -t $session
end
