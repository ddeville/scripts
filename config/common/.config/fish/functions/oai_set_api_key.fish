function oai_set_api_key --description "Load and set OpenAI API key"
    set config_path "$HOME/.config/openai/api_key.json"

    if test -e $config_path
        set -gx OPENAI_API_KEY (jq .OPENAI_API_KEY --raw-output $config_path)
        set -gx OPENAI_API_BASE (jq .OPENAI_API_BASE --raw-output $config_path)
    else
        if test "$argv[1]" != silent
            echo "ERROR: You need to add your key to $config_path"
        end
    end
end
