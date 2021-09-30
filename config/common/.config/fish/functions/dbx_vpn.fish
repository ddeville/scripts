function dbx_vpn --description "Forward port to Dropbox Mac Pro and set up proxy on it"
    set port 45623
    set network_service $argv[1]
    set server $argv[2]

    if test -d $network_service
        echo "No network service given, defaulting to Ethernet"
        set network_service "Ethernet"
    end
    if test -d $server
        echo "No server given, defaulting to damien-mp.home.kattungar.net"
        set server "damien-mp.home.kattungar.net"
    end

    if [ (uname -s) = "Darwin" ]
        echo "Enabling SOCKS proxy on" $network_service "with port" $port
        command networksetup -setsocksfirewallproxy $network_service localhost $port
        command networksetup -setsocksfirewallproxystate $network_service on
    end

    echo "SSH connecting to" $server
    echo "SSH binding to port" $port
    command ssh -D $port -N $server

    if [ (uname -s) = "Darwin" ]
        echo "Disabling SOCKS proxy"
        command networksetup -setsocksfirewallproxystate $network_service off
    end
end
