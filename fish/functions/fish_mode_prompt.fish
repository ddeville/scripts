function fish_mode_prompt
    switch $fish_bind_mode
        case insert
            set_color green
            echo '[I]'
        case default
            set_color magenta
            echo '[N]'
        case visual
            set_color cyan 
            echo '[V]'
        case replace_one
            set_color green
            echo '[R]'
        end
        set_color normal
        echo -n ' '
end
