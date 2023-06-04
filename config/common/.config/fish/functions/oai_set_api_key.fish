function oai_set_api_key --description "Load and set OpenAI API key"
    set config_path "$HOME/.config/openai/api_key"

    if test -e $config_path
        set -gx OPENAI_API_KEY (cat "$config_path/OPENAI_API_KEY")
        set -gx OPENAI_API_BASE (cat "$config_path/OPENAI_API_BASE")
    else
        if test "$argv[1]" != silent
            echo "ERROR: You need to add your key to $config_path"
        end
    end
end
