function dbx_vpn
    if count $argv > /dev/null
        while true
            ssh -D $argv[1] -N damien@damien-mbp.local
            sleep 5
        end
    else
        echo "You need to pass a port to bind!"
    end
end
