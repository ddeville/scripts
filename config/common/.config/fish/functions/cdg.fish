function cdg --description "Change directory to the nearest parent that is the root of a git repository"
    while test $PWD != "/"
        if test -d .git
            break
        end
        cd ..
    end
end
