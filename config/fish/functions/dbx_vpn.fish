function dbx_vpn
    set port 45623
    set network_service Wi-Fi
    set server damien@damien-mp.local

    echo "Enabling SOCKS proxy on" $network_service "with port" $port
    command networksetup -setsocksfirewallproxy $network_service localhost $port
    command networksetup -setsocksfirewallproxystate $network_service on

    echo "SSH connecting to" $server
    echo "SSH binding to port" $port
    command ssh -D $port -N $server

    echo "Disabling SOCKS proxy"
    command networksetup -setsocksfirewallproxystate $network_service off
end
