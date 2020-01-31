function ssh_fix --description "Load and add the current SSH key to the session"
    eval (ssh-agent -c)
    ssh-add -K ~/.ssh/id_rsa
end
