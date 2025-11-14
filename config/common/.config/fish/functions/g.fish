function g
    if test (count $argv) -eq 0
        command git status
    else
        command git $argv
    end
end
