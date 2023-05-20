function git_cleanup_branches --description "Cleanup local branches that used to have an upstream that was deleted"
    git fetch --prune

    for branch in (git branch -vv | grep -o -E '^[\* ]+\S+' | tr -d '* ')
        set upstream (git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null)
        if test -n "$upstream"
            if not git show-ref --quiet refs/remotes/"$upstream"
                echo "Deleting branch '$branch'"
                git branch -D "$branch"
            end
        end
    end
end
