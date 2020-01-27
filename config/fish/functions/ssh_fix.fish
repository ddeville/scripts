function ssh_fix
    eval (ssh-agent -c)
    ssh-add -K ~/.ssh/id_rsa
end
