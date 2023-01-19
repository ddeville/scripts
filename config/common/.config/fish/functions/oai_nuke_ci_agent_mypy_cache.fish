function oai_nuke_ci_agent_mypy_cache --description "Delete the cache on all the ci-agent pods"
    set ctx internal-ci-api
    set label "app=ci-agent"
    kubectl --context $ctx get pods -o name -l $label | xargs -I{} kubectl --context $ctx exec {} -- /bin/bash -c "rm -rf /tmp/mypy-cache"
end
