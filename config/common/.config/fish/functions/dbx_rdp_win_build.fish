function dbx_rdp_win_build --description "Setup RDP connection to the Windows build machine"
    ssh -N -L 13389:clientbuild-win01:3389 damien@build-ssh.corp.dropbox.com -J damien@damien-studio.home.kattungar.net
end
