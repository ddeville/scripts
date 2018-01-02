function fish_mode_prompt
    switch $fish_bind_mode
        case insert
            set_color 8abeb7
            echo '[I]'
        case replace_one
            set_color 8abeb7
            echo '[R]'
        case default
            set_color f0c674
            echo '[C]'
        case visual
            set_color cc6666 
            echo '[V]'
        end
        set_color normal
        echo -n ' '
end
