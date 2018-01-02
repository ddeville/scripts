function fish_mode_prompt
    switch $fish_bind_mode
        case insert
            set_color --bold --background green black
            echo '[I]'
        case default
            set_color --bold --background magenta black
            echo '[N]'
        case visual
            set_color --bold --background cyan black
            echo '[V]'
        case replace_one
            set_color --bold --background green black
            echo '[R]'
        end
        set_color normal
        echo -n ' '
end
