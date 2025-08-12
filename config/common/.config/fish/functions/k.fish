function k
    if test (count $argv) -eq 0
        kubectl get pod
    else
        kubectl $argv
    end
end
