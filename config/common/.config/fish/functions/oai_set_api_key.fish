function oai_set_api_key --description "Load and set OpenAI API key"
    set config_path "$HOME/.config/openai/api_key.fish"

    if test -e $config_path
        source "$config_path"
    else
        if test "$argv[1]" != silent
            echo "ERROR: You need to add your key to $config_path"
        end
    end
end
