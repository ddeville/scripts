function openai_checkout_api_pins --description "Checkout whatever is the current version for pinned repos in API"
    set -l code_dir "$HOME/code"
    set -l manage_dir "$code_dir/api/manage"

    pushd "$code_dir/model-runner-api"
    git fetch && git checkout (cat "$manage_dir/model-runner-api.version")
    popd

    pushd "$code_dir/openai-python"
    git fetch && git checkout (cat "$manage_dir/openai-python.version")
    popd
end