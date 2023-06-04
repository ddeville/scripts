function oai_tmux --description "Create OAI tmux sessions"
    if test -n "$TMUX"
        echo "You cannot create tmux sessions inside of tmux."
        return 1
    end
    if command tmux list-sessions >/dev/null 2>&1
        echo "There are some existing sessions in tmux, first kill them."
        return 1
    end

    command tmux new-session -D -s api -d -c ~/code/api
    command tmux rename-window -t api:1 repo
    command tmux new-window -t api -n editor -d -c ~/code/api
    command tmux send-keys -t api:2 "nvim ." Enter

    command tmux new-session -D -s openai-py -d -c ~/code/openai-python
    command tmux rename-window -t openai-py:1 repo
    command tmux new-window -t openai-py -n editor -d -c ~/code/openai-python
    command tmux send-keys -t openai-py:2 "nvim ." Enter

    command tmux new-session -D -s monorepo -d -c ~/code/openai
    command tmux rename-window -t monorepo:1 repo
    command tmux new-window -t monorepo -n editor -d -c ~/code/openai
    command tmux send-keys -t monorepo:2 "nvim ." Enter

    command tmux new-session -D -s scripts -d -c ~/scripts
    command tmux rename-window -t scripts:1 repo
    command tmux new-window -t scripts -n editor -d -c ~/scripts
    command tmux send-keys -t scripts:2 "nvim ." Enter
    command tmux new-window -t scripts -n notes -d -c ~/Desktop
    command tmux send-keys -t scripts:3 "nvim notes.txt" Enter

    command tmux switch-client -t api
    command tmux select-window -t api:1
    command tmux attach -d -t api
end
