function gcm
    set default (git symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
    git checkout $default
end
