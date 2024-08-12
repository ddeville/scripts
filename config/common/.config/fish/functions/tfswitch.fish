function tfswitch
    if not type -fq tfswitch
        echo "tfswitch is not installed, this is just a fish function wrapper!"
        return 1
    end

    command tfswitch --install "$HOME/.local/toolchains/terraform" --bin $HOME/.local/bin/terraform $argv
end
