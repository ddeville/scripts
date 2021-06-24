function fish_user_key_bindings
    if test -e $XDG_DATA_HOME/fzf/shell/key-bindings.fish
        source $XDG_DATA_HOME/fzf/shell/key-bindings.fish
        fzf_key_bindings
    end
end
