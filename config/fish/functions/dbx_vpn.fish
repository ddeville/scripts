function dbx_vpn
    set port 45623
    set server damien@damien-mbp.local

    echo "Disabling proxy on port" $port
    command networksetup -setsocksfirewallproxy Wi-Fi localhost $port
    command networksetup -setsocksfirewallproxystate Wi-Fi on

    echo "SSH connecting to" $server
    echo "SSH binding to port" $port
    command ssh -D $port -N $server

    echo "Disabling SOCKS proxy"
    command networksetup -setsocksfirewallproxystate Wi-Fi off
end
