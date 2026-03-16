function pyvenv --description "Activate the global Python venv"
    set -l toolchains_home "$XDG_TOOLCHAINS_HOME"
    if test -z "$toolchains_home"
        set toolchains_home "$HOME/.local/toolchains"
    end

    set -l global_venv "$toolchains_home/python/global/venv/global"
    set -l activate_path "$global_venv/bin/activate.fish"

    if not test -e "$activate_path"
        echo "Global Python venv not found at $global_venv. Run: pypkg"
        return 1
    end

    set -e PYTHONHOME
    set -l VIRTUAL_ENV_DISABLE_PROMPT 1
    source "$activate_path"
end
