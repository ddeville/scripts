function dbx_rdp_win_build --description "Setup RDP connection to the Windows build machine"
    ssh -i ~/.ssh/dbx_id_rsa -N -L 13389:clientbuild-win01:3389 damien@build-ssh.corp.dropbox.com -J damien@damien-mp.home.kattungar.net
end
