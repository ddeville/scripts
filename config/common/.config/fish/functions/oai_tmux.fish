function oai_tmux --description "Create OAI tmux sessions"
    if test -n "$TMUX"
        echo "You cannot create tmux sessions inside of tmux."
        return 1
    end
    if command tmux list-sessions >/dev/null 2>&1
        echo "There are some existing sessions in tmux, first kill them."
        return 1
    end

    # The API session
    command tmux new-session -D -s api -d -c ~/code/api
    command tmux rename-window -t api:1 repo
    command tmux new-window -t api -n editor -d -c ~/code/api
    command tmux send-keys -t api:2 "nvim ." Enter

    # The openai-py session
    command tmux new-session -D -s openai-py -d -c ~/code/openai-python
    command tmux rename-window -t openai-py:1 repo
    command tmux new-window -t openai-py -n editor -d -c ~/code/openai-python
    command tmux send-keys -t openai-py:2 "nvim ." Enter

    # The Terraform session
    command tmux new-session -D -s terraform -d -c ~/code/terraform-config-api
    command tmux rename-window -t terraform:1 repo
    command tmux new-window -t terraform -n editor -d -c ~/code/terraform-config-api
    command tmux send-keys -t terraform:2 "nvim ." Enter

    # The scripts and notes session
    command tmux new-session -D -s scripts -d -c ~/scripts
    command tmux rename-window -t scripts:1 repo
    command tmux new-window -t scripts -n editor -d -c ~/scripts
    command tmux send-keys -t scripts:2 "nvim ." Enter
    command tmux new-window -t scripts -n notes -d -c ~/Desktop
    command tmux send-keys -t scripts:3 "nvim notes.txt" Enter

    # Select the API session
    command tmux switch-client -t api
    command tmux select-window -t api:1
    command tmux attach -d -t api
end
