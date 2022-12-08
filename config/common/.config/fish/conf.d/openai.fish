set -x OPENAI_USER "$USER"
set -x API_REPO_PATH "$HOME/code/api"

# 1. Set `KUBECONFIG` to its default value if it wasn't set
# 2. Prepend `API_KUBECONFIG` to it in all cases
if set -q KUBECONFIG
    set CURRENT_KUBECONFIG "$KUBECONFIG"
else
    set CURRENT_KUBECONFIG "$HOME/.kube/config"
end
set API_KUBECONFIG "$HOME/.kube/api_config"
switch "$KUBECONFIG"
case "$API_KUBECONFIG:*"
case "*"
    set -x KUBECONFIG "$API_KUBECONFIG:$CURRENT_KUBECONFIG"
end

function buildbox_activate
    set -gx DOCKER_HOST build-box.internal.api.openai.org:2376
    set -gx DOCKER_TLS_VERIFY 1
    set -gx DOCKER_CERT_PATH "$HOME/.docker/build-box"
end

function nicer_kubectl
    set cluster $argv[1]
    if test (count $argv) -eq 1
        if test $COLUMNS -gt 200
            kubectl --context="$cluster" get pods -o wide
        else
            kubectl --context="$cluster" get pods
        end
    else
        kubectl --context="$cluster" $argv[2..-1]
    end
end

function azssh
    # Usage: azssh <IP> for any VM IP with aadsshlogin enabled
    #  workaround https://github.com/Azure/azure-cli-extensions/issues/4026
    az ssh vm --ip $argv -- -o PubkeyAcceptedKeyTypes=+ssh-rsa-cert-v01@openssh.com
end

alias acrlogin "az login && az acr login -n openaiapiglobal --subscription api"

alias engine-doctor-prod "admin-openai engines.doctor -e prod -i"
alias engine-doctor-staging "admin-openai engines.doctor -e staging -i"

## STAGING CLUSTERS
alias staging-primary-aks-scus-api-b "nicer_kubectl staging-primary-aks-scus-api-b"
alias staging-engine-aks-scentralus-output "nicer_kubectl staging-engine-aks-scentralus-output"
alias staging-first-party-aks-scus-api-b "nicer_kubectl staging-first-party-aks-scus-api-b"

alias sp "staging-primary-aks-scus-api-b"
alias x "staging-engine-aks-scentralus-output"
alias s1p "staging-first-party-aks-scus-api-b"

## PROD CLUSTERS
alias prod-primary-aks-scentralus-api-b "nicer_kubectl prod-primary-aks-scentralus-api-b"
alias prod-first-party-aks-scentralus-api-b "nicer_kubectl prod-first-party-aks-scentralus-api-b"
alias prod-engine-aks-scentralus-output "nicer_kubectl prod-engine-aks-scentralus-output"
alias prod-engine-aks-eastus-output "nicer_kubectl prod-engine-aks-eastus-output"
alias prod-engine-aks-westus2-output "nicer_kubectl prod-engine-aks-westus2-output"
alias prod-engine-aks-eastus2-output "nicer_kubectl prod-engine-aks-eastus2-output"
alias prod-engine-aks-centralus-api-loan "nicer_kubectl prod-engine-aks-centralus-api-loan"  # Loan cluster from research
alias prod-engine-aks-centralus-panda "nicer_kubectl prod-engine-aks-centralus-panda"  # Loan cluster from research

alias p "prod-primary-aks-scentralus-api-b"
alias 1p "prod-first-party-aks-scentralus-api-b"
alias c5 "prod-engine-aks-scentralus-output"
alias c6 "prod-engine-aks-eastus-output"
alias c7 "prod-engine-aks-westus2-output"
alias c8 "prod-engine-aks-eastus2-output"
alias c9 "prod-engine-aks-centralus-api-loan"
alias c10 "prod-engine-aks-centralus-panda"

# INTERNAL CLUSTERS
alias internal-ci-api "nicer_kubectl internal-ci-api"
alias internal-admin-prod-api "nicer_kubectl internal-admin-prod-api"
alias internal-admin-staging-api "nicer_kubectl internal-admin-staging-api"
alias prod-admin-westus2-output "nicer_kubectl prod-admin-westus2-output"
alias staging-admin-westus2-output "nicer_kubectl staging-admin-westus2-output"

alias ci "internal-ci-api"
alias admin-old "internal-admin-prod-api"
alias sadmin-old "internal-admin-staging-api"
alias admin "prod-admin-westus2-output"
alias sadmin "staging-admin-westus2-output"

# kubectl_preflight is a hacky script that takes a kube context name and attempts
# to use it to verify that you are able to access it. It's meant to handle weird
# edge cases where you need to re-auth due to 2FA expiration in your az login
# or other token expiration. Hopefully we will soon rarely need to use it in prod!
alias kubectl_preflight "python $API_REPO_PATH/manage/dev_setup/kubectl_preflight.py"
