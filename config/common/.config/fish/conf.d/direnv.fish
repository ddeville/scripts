if command -v direnv &>/dev/null
    direnv hook fish | source
end

set -g direnv_fish_mode disable_arrow
