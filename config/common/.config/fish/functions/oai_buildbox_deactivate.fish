function oai_buildbox_deactivate --description "Remove the remote buildbox env variables"
    set --unexport DOCKER_HOST
    set --erase DOCKER_HOST
    set --unexport DOCKER_TLS_VERIFY
    set --erase DOCKER_TLS_VERIFY
    set --unexport DOCKER_CERT_PATH
    set --erase DOCKER_CERT_PATH
end
