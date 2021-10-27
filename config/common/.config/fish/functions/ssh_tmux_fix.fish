function ssh_tmux_fix --description "Update the env var to the latest ssh sock"
    if test -n "$TMUX"
        set env_var (tmux show-environment | grep "^SSH_AUTH_SOCK=")
        if test -n "$env_var"
            export $env_var
        end
    end
end
