set -l OPENAI_MACHINES oai-damien

# We only ever need to run this on an oai machine
if not contains (hostname) "$OPENAI_MACHINES"
    return
end

set -gx OPENAI_USER "$USER"
set -gx API_REPO_PATH "$HOME/code/api"
set -gx KUBECONFIG "$HOME/.kube/api_config"(set -q KUBECONFIG; and echo ":$KUBECONFIG"; or echo)

oai_set_api_key silent
oai_buildbox_activate silent

function acrlogin
    rm -f $HOME/.azure/msal_token_cache.json
    rm -rf $HOME/.kube/cache/kubelogin/
    az account clear
    az login
    az acr login -n openaiapiglobal --subscription api
end

alias a applied
alias ak "applied kubectl"
alias ad "applied deploy"
alias at "applied test"
alias aa "applied autogen"

if test -e "$API_REPO_PATH/devtools/completions/applied_completions.fish"
    source "$API_REPO_PATH/devtools/completions/applied_completions.fish"
end
