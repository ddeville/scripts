function kk
    if test (count $argv) -eq 0
        echo "Usage: kk <context>"
        return 1
    end
    if test (count $argv) -eq 1
        kubectl --context=$argv[1] get pod
    else
        kubectl --context=$argv[1] $argv[2..-1]
    end
end
