function oai_buildbox_activate --description "Set the env variables necessary to use the remote buildbox"
    set config_path "$HOME/.config/openai/buildbox/docker.fish"

    if test -e $config_path
        source "$config_path"
    else
        if test "$argv[1]" != silent
            echo "ERROR: You need to add the Docker host path to $config_path"
        end
    end
end
