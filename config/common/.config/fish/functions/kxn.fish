function kxn
    if test (count $argv) -ne 2
        echo "Usage: kx <context> <ns>"
        return 1
    end
    kubectl config use-context $argv[1]
    kubectl config set-context --current --namespace=$argv[2]
end
