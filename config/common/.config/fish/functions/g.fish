function g
    if test (count $argv) -eq 0
        git status
    else
        git $argv
    end
end
