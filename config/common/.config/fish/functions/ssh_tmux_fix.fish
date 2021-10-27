function ssh_tmux_fix --description "Update the env var to the latest ssh sock"
    export (tmux show-environment | grep "^SSH_AUTH_SOCK")
end
