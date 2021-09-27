function dbx_tmux_home --description "Create Dropbox tmux session on home machine"
    set session "dbx"
    if not command tmux list-sessions 2> /dev/null | grep $session > /dev/null 2>&1
        # create the session at ~
        command tmux new-session -D -s $session -d -c ~

        # repo
        command tmux new-window -t $session -n "desktop" -d -c ~/src/dropbox/server/desktop

        # editor
        command tmux new-window -t $session -n "editor" -d -c ~/src/dropbox/server/desktop
        command tmux send-keys -t $session:3 "nvim ." Enter

        # server
        command tmux new-window -t $session -n "server" -d -c ~/src/dropbox/server

        # server-ed
        command tmux new-window -t $session -n "server-ed" -d -c ~/src/dropbox/server
        command tmux send-keys -t $session:5 "nvim ." Enter

        # vpn
        command tmux new-window -t $session -n "vpn" -d -c ~
        command tmux send-keys -t $session:6 "sshuttle -r damien@damien-mp.corp.kattungar.net --dns 0.0.0.0/0" Enter
        command tmux new-window -t $session -n "vpn-mp" -d -c ~
        command tmux send-keys -t $session:7 "ssh damien@damien-mp.corp.kattungar.net" Enter

        # scripts
        command tmux new-window -t $session -n "scripts" -d -c ~/scripts

        # let's now kill the original window and move them all back by 1
        command tmux kill-window -t $session:1
        command tmux move-window -s $session:2 -t $session:1
        command tmux move-window -s $session:3 -t $session:2
        command tmux move-window -s $session:4 -t $session:3
        command tmux move-window -s $session:5 -t $session:4
        command tmux move-window -s $session:6 -t $session:5
        command tmux move-window -s $session:7 -t $session:6
        command tmux move-window -s $session:8 -t $session:7

        # and select the first one
        command tmux select-window -t $session:1
    end
    command tmux attach -d -t $session
end
