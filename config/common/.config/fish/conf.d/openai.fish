set -x OPENAI_USER "$USER"
set -x API_REPO_PATH "$HOME/code/api"

alias acrlogin "az login && az acr login -n openaiapiglobal --subscription api"
