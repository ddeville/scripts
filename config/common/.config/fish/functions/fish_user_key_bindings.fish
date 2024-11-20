function fish_user_key_bindings
    # When on macos, the keybindings have to be sourced manually.
    if test (uname) = Darwin
        if test -e "/opt/homebrew/opt/fzf/shell/key-bindings.fish"
            source /opt/homebrew/opt/fzf/shell/key-bindings.fish
        else if test -e "/usr/local/opt/fzf/shell/key-bindings.fish"
            source /usr/local/opt/fzf/shell/key-bindings.fish
        end
    end

    # On a linux devbox, fzf is likely installed from linuxbrew.
    if test (uname) = Linux
        if test -e "/home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.fish"
            source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.fish
        end
    end

    # NOTE: When installing fzf via pacman on arch linux, the key bindings are
    # installed and sourced automatically from
    # `/usr/share/fish/vendor_functions.d/fzf_key_bindings.fish` but need to be
    # manually activated here.

    if type -q fzf_key_bindings
        fzf_key_bindings
    end
end
