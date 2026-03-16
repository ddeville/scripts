function pyvenv --description "Activate the global Python venv"
    set -l global_venv "$VENV_INSTALL_DIR/global"
    set -l activate_path "$global_venv/bin/activate.fish"

    if not test -e "$activate_path"
        echo "Global Python venv not found at $global_venv. Run: pypkg"
        return 1
    end

    set -e PYTHONHOME
    set -l VIRTUAL_ENV_DISABLE_PROMPT 1
    source "$activate_path"
end
