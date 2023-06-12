function tmux_refresh_environment --description "Refresh the current environment variables in the shell from their tmux counterpart"
    for line in (tmux show-environment)
        if string match -qr '^-.*' -- "$line"
            set --global --erase (string replace "-" "" -- "$line")
        else
            set --global --export (string replace -r '=.*' '' -- "$line") (string replace -r ".*=" "" -- "$line")
        end
    end
end
