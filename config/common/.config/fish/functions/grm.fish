function grm
    set default (git symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
    git rebase $default
end
