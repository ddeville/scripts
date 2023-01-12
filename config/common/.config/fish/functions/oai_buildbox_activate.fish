function oai_buildbox_activate --description "Set the env variables necessary to use the remote buildbox"
    set config_path "$HOME/.config/openai/buildbox/config.json"

    if test -e $config_path
        set -gx DOCKER_HOST (jq .DOCKER_HOST --raw-output $config_path)
        set -gx DOCKER_TLS_VERIFY 1
        set -gx DOCKER_CERT_PATH (jq .DOCKER_CERT_PATH --raw-output $config_path)
    else
        if test "$argv[1]" != silent
            echo "ERROR: You need to add the Docker host path to $config_path"
        end
    end
end
