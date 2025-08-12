function kx
    if test (count $argv) -eq 0
        echo "Usage: kx <context>"
        return 1
    end
    kubectl config use-context $argv[1]
end
