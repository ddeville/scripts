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

    set -l cyan (set_color --bold 8abeb7)
    set -l yellow (set_color --bold f0c674)
    set -l red (set_color --bold cc6666)
    set -l blue (set_color --bold 81a2be)
    set -l normal (set_color normal)

    set -l arrow "$red➜ "
    if [ $USER = 'root' ]
        set arrow "$red# "
    end
  
    set -l cwd_ $cyan(basename (prompt_pwd))
    set -l hostname_ $yellow(hostname -s)

    if [ (_is_git_repo) ]
        set -l repo_branch $red(_git_branch_name)
        set repo_info "$blue:($repo_branch$blue)"
    end

    echo -n -s $arrow ' '$hostname_:$cwd_ $repo_info $normal ' '
end
