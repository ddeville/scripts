function kat_nas --description "Connect to Synology and start/join a tmux session"
    command ssh damien@nas.home.kattungar.net -t "/usr/local/bin/tmux new-session -D -s nas -c ~ || /usr/local/bin/tmux attach -d -t nas"
end
