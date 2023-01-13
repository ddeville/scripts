set -l OPENAI_MACHINES oai-damien

# We only ever need to run this on an oai machine
if not contains (hostname) "$OPENAI_MACHINES"
    return
end

set -gx OPENAI_USER "$USER"
set -gx API_REPO_PATH "$HOME/code/api"

oai_set_api_key silent
oai_buildbox_activate silent

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

function azssh
    # Usage: azssh <IP> for any VM IP with aadsshlogin enabled
    #  workaround https://github.com/Azure/azure-cli-extensions/issues/4026
    az ssh vm --ip $argv -- -o PubkeyAcceptedKeyTypes=+ssh-rsa-cert-v01@openssh.com
end

alias acrlogin "az login && az acr login -n openaiapiglobal --subscription api"

# This function is used by the aliases created below
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

set -l oia_script_path "$API_REPO_PATH/manage/dev_setup/bash_or_zsh_rc"

# Read all the aliases from Bash and turn them into Fish aliases, ugh...
if test -e $oia_script_path
    for line in (cat $oia_script_path)
        if string match --regex "^alias *" $line >/dev/null
            set line (string replace --regex "^alias *" "" $line)
            set entry (string split "=" $line)

            set value $entry[2]
            set value (string replace -a "'" "" $value)
            set value (string replace -a '"' "" $value)

            alias $entry[1] "$value"
        end
    end
end
