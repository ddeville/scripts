function oai_buildbox_activate --description "Set the env variables necessary to use the remote buildbox"
    set -gx DOCKER_HOST build-box.internal.api.openai.org:2376
    set -gx DOCKER_TLS_VERIFY 1
    set -gx DOCKER_CERT_PATH "$HOME/.docker/build-box"
end
