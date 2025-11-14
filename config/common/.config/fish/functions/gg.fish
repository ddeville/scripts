function gg
    if test (count $argv) -eq 0
        echo "Usage: gg <name>"
        return 1
    end
    git checkout -b damien/$argv[1]
end
