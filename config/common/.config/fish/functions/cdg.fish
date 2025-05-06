function cdg --description "Change to the nearest parent that is a git root"
    set -l target $PWD

    while test $target != /
        if test -d "$target/.git"
            break
        end
        set target (dirname $target)
    end

    cd $target
end
