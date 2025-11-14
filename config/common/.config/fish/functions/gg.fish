function gg
    if test (count $argv) -eq 0
        echo "Usage: gg <name>"
        return 1
    end
    command git checkout -b damien/$argv[1]
end
