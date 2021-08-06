function ssh_fix --description "Load and add the current SSH key to the session"
    eval (ssh-agent -c)
    if test -e ~/.ssh/id_rsa
        set path ~/.ssh/id_rsa
    else if test -e ~/.ssh/id_ed25519
        set path ~/.ssh/id_ed25519
    else
        set path "MISSING_SSH_KEY"
    end
    switch (uname)
        case Darwin
            ssh-add -K $path
        case '*'
            ssh-add $path
    end
end
