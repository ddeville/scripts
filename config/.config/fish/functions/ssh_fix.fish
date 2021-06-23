function ssh_fix --description "Load and add the current SSH key to the session"
    eval (ssh-agent -c)
    switch (uname)
        case Darwin
            ssh-add -K ~/.ssh/id_rsa
        case '*'
            ssh-add ~/.ssh/id_rsa
    end
end
