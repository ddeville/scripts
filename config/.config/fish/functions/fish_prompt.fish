function fish_prompt
    if not set -q -g __fish_git_functions_defined
        set -g __fish_git_functions_defined

        function _is_git_repo
            git rev-parse --is-inside-work-tree ^/dev/null
        end

        function _git_branch_name
            echo (git symbolic-ref HEAD ^/dev/null | sed -e "s|^refs/heads/||")
        end
    end

    set -l cwd_color (set_color $fish_color_cwd)
    set -l yellow (set_color yellow)
    set -l red (set_color red)
    set -l normal_color (set_color $fish_color_normal)

    if test "$USER" = "root"
        set prompt_sign "#"
    else
        set prompt_sign ">"
    end

    set -l cwd_ $cwd_color(basename (prompt_pwd))
    set -l hostname_ $yellow(hostname -s)

    if test (_is_git_repo)
        set -l repo_branch $red(_git_branch_name)
        set repo_info "$normal_color:($repo_branch$normal_color)"
    end

    echo -n -s $hostname_$normal_color:$cwd_ $repo_info $normal_color" "$normal_color$prompt_sign" "

    set_color normal
end

function fish_right_prompt
    set_color brblack
    date "+%T"
    set_color normal
end
