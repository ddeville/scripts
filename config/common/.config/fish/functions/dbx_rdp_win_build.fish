function dbx_rdp_win_build --description "Setup RDP connection to the Windows build machine"
    if not ssh-add -l 2> /dev/null | grep dbx_id_rsa > /dev/null 2>&1
        ssh-add ~/.ssh/dbx_id_rsa
    end
    ssh -N -L 13389:clientbuild-win01:3389 damien@build-ssh.corp.dropbox.com -J damien@damien-mp.home.kattungar.net
end
