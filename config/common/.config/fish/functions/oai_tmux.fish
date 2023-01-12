function oai_tmux --description "Create OAI tmux session"
    set session oai
    if not command tmux list-sessions 2>/dev/null | grep $session >/dev/null 2>&1
        # create the session at ~
        command tmux new-session -D -s $session -d -c ~

        # api
        command tmux new-window -t $session -n api -d -c ~/code/api

        # editor
        command tmux new-window -t $session -n editor -d -c ~/code/api
        command tmux send-keys -t $session:3 "nvim ." Enter

        # tf
        command tmux new-window -t $session -n tf -d -c ~/code/terraform-config-api

        # scripts
        command tmux new-window -t $session -n scripts -d -c ~/scripts

        # notes
        command tmux new-window -t $session -n notes -d -c ~/Desktop
        command tmux send-keys -t $session:6 "nvim notes.txt" Enter

        # openai-python
        command tmux new-window -t $session -n openai-py -d -c ~/code/openai-python

        # let's now kill the original window and move them all back by 1
        command tmux kill-window -t $session:1
        command tmux move-window -s $session:2 -t $session:1
        command tmux move-window -s $session:3 -t $session:2
        command tmux move-window -s $session:4 -t $session:3
        command tmux move-window -s $session:5 -t $session:4
        command tmux move-window -s $session:6 -t $session:5
        command tmux move-window -s $session:7 -t $session:6

        # and select the first one
        command tmux select-window -t $session:1
    end
    command tmux attach -d -t $session
end
