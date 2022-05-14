function dbx_rdp_win_devbox --description "Setup RDP connection to my Windows devbox"
    ssh -N -L 23389:damien-win1:3389 damien@damien-studio.home.kattungar.net
end
