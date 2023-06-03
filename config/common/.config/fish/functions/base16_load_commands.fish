function base16_load_commands --description "Load the base16 commands to allow switching theme"
    set -l base16_path "$XDG_DATA_HOME/base16/base16-shell/profile_helper.fish"
    if test -e $base16_path
        source $base16_path
    else
        echo "Looks like base16 isn't install, run `update-shell-plugins`."
    end
end
