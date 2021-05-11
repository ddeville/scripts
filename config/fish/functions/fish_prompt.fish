function fish_prompt
    if not set -q -g __fish_git_functions_defined
        set -g __fish_git_functions_defined

        function _is_git_repo
            git rev-parse --is-inside-work-tree ^/dev/null
        end

        function _git_branch_name
            echo (git symbolic-ref HEAD ^/dev/null | sed -e 's|^refs/heads/||')
        end
    end

    set -l cwd_color (set_color --bold $fish_color_cwd)
    set -l yellow (set_color --bold f0c674)
    set -l red (set_color --bold cc6666)
    set -l normal_color (set_color $fish_color_normal)

    set -l arrow "$red➜ "
    if [ $USER = 'root' ]
        set arrow "$red# "
    end

    set -l cwd_ $cwd_color(basename (prompt_pwd))
    set -l hostname_ $yellow(hostname -s)

    if [ (_is_git_repo) ]
        set -l repo_branch $red(_git_branch_name)
        set repo_info "$normal_color:($repo_branch$normal_color)"
    end

    echo -n -s $arrow ' '$hostname_:$cwd_ $repo_info $normal_color ' '
end
