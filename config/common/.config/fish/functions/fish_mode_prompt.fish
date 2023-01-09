function fish_mode_prompt
    switch $fish_bind_mode
        case insert
            set_color brgreen
            echo "[I]"
        case replace_one
            set_color brgreen
            echo "[R]"
        case default
            set_color brcyan
            echo "[N]"
        case visual
            set_color brred
            echo "[V]"
    end
    set_color normal
    echo -n " "
end
