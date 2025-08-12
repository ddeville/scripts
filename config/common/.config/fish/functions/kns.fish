function kns
    if test (count $argv) -eq 0
        echo "Usage: kns <namespace>"
        return 1
    end
    kubectl config set-context --current --namespace=$argv[1]
end
