function cdg --description "Change to the current git repo root"
    set -l root (git rev-parse --show-toplevel 2>/dev/null)

    if test -z "$root"
        return 1
    end

    cd "$root"
end
