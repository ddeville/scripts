function dbx_tmux --description "Create Dropbox tmux session"
    set session "dbx"
    if not command tmux list-sessions | grep $session > /dev/null 2>&1
        # create the session at ~
        command tmux new-session -D -s $session -d -c ~

        # repo
        command tmux new-window -t $session -n "repo" -d -c ~/src/client

        # editor
        command tmux new-window -t $session -n "editor" -d -c ~/src/client
        command tmux send-keys -t $session:3 "nvim ." Enter

        # server
        command tmux new-window -t $session -n "server" -d -c ~/src/server

        # server-ed
        command tmux new-window -t $session -n "server-ed" -d -c ~/src/server
        command tmux send-keys -t $session:5 "nvim ." Enter

        # vpn
        command tmux new-window -t $session -n "vpn" -d -c ~

        # let's now kill the original window and move them all back by 1
        command tmux kill-window -t $session:1
        command tmux move-window -s $session:2 -t $session:1
        command tmux move-window -s $session:3 -t $session:2
        command tmux move-window -s $session:4 -t $session:3
        command tmux move-window -s $session:5 -t $session:4
        command tmux move-window -s $session:6 -t $session:5

        # and select the first one
        command tmux select-window -t $session:1
    end
    command tmux attach -d -t $session
end
