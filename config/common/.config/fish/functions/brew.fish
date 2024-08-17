function brew
    if not type -fq brew
        echo "brew is not installed, this is just a fish function wrapper!"
        return 1
    end

    set cmd $argv[1]

    command brew $argv

    switch "$cmd"
        case install uninstall upgrade
            if test (uname) = Linux; and test -e /home/linuxbrew/.filtered; and type -fq filter-brew-leaf-packages
                echo "Updating symlinks for filtered packages..."
                command filter-brew-leaf-packages
            end
    end
end
