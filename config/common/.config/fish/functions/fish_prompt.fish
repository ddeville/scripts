function fish_prompt
    if not set -q -g __fish_git_functions_defined
        set -g __fish_git_functions_defined

        function _is_git_repo
            git rev-parse --is-inside-work-tree 2>/dev/null
        end

        function _git_branch_name
            echo (git symbolic-ref HEAD 2>/dev/null | sed -e "s|^refs/heads/||")
        end

        function _pyenv_virtualenv_name
            echo (basename "$VIRTUAL_ENV")
        end
    end

    set -l cwd_color (set_color $fish_color_cwd)
    set -l host_color (set_color yellow)
    set -l branch_color (set_color red)
    set -l venv_color (set_color cyan)
    set -l normal_color (set_color $fish_color_normal)

    if test "$USER" = root
        set prompt_sign "#"
    else
        set prompt_sign ">"
    end

    set -l cwd_ $cwd_color(basename (prompt_pwd))
    set -l hostname_ $host_color(hostname -s)

    if set -q VIRTUAL_ENV
        set -l venv_name $venv_color(_pyenv_virtualenv_name)
        set venv_info "$normal_color:[$venv_name]$normal_color"

    end

    if test (_is_git_repo)
        set -l repo_branch $branch_color(_git_branch_name)
        set repo_info "$normal_color:($repo_branch$normal_color)"
    end

    echo -n -s $hostname_$normal_color:$cwd_ $venv_info $repo_info $normal_color" "$normal_color$prompt_sign" "

    set_color normal
end

function fish_right_prompt
    set_color brblack
    date "+%l:%M:%S %p"
    set_color normal
end
