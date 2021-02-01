function install_nvim_nightly --description "Install the Nightly version of Neovim"
    set install_path "/opt/nvim_nightly"

    # Create install path if needed
    if not test -e $install_path
        echo "Creating install folder"
        command sudo mkdir $install_path
        command sudo chown $USER $install_path
    end

    # Make sure it's a folder with the right permissions
    if not test -e $install_path; or not test -d $install_path; or not test -O $install_path
        echo "Make sure that" $install_path "is a directory and is owned by" $USER
        return 1
    end

    # Get the download URL for the nightly package for the current platform
    if test (uname) = "Darwin"
        set filename "nvim-macos.tar.gz"
        set foldername "nvim-osx64"
    else if test (uname) = "Linux"
        set filename "nvim-linux64.tar.gz"
        set foldername "nvim-linux64"
    else
        echo "Unsupported platform:" (uname)
        return 1
    end
    set url "https://github.com/neovim/neovim/releases/download/nightly/"{$filename}

    # Download the archive to a temp directory
    set tmp_dir (mktemp -d)
    set tmp_path {$tmp_dir}"/"{$filename}
    echo "Downloading" $url "to" $tmp_path
    command curl -L --url $url --output $tmp_path

    # Extract the archive
    command tar xzvf $tmp_path -C $tmp_dir
    command rm $tmp_path

    # Delete the existing install and move the new one over
    command touch {$install_path}"/sentinel"
    command rm -rf {$install_path}"/"*
    command mv {$tmp_dir}"/"{$foldername}"/"* $install_path

    # Cleanup
    command rm -r {$tmp_dir}"/"{$foldername}
end
