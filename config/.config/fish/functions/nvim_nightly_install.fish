function nvim_nightly_install --description "Install the Nightly version of Neovim, either by downloading it pre-built or by compiling it"
    switch $argv[1]
        case prebuilt
            _nvim_nightly_prebuilt
        case compile
            _nvim_nightly_compile
        case "*"
            echo "Available commands:"
            echo "  * prebuilt"
            echo "  * compile"
            return 1
    end
end

set NVIM_INSTALL_PATH "/opt/nvim/nightly"

function _nvim_nightly_prebuilt --description "Download the pre-built Nightly version of Neovim"
    _setup
    if test $status -ne 0
        return $status
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

    # Check whether it is a new version
    set new_version (command {$tmp_dir}"/"{$foldername}"/bin/nvim" --version | head -n 1)
    if test -e {$NVIM_INSTALL_PATH}"/bin/nvim"
        set cur_version (command {$NVIM_INSTALL_PATH}"/bin/nvim" --version | head -n 1)

        if test $cur_version = $new_version
            echo "Version" $cur_version "is already installed"
            # Cleanup
            command rm -rf {$tmp_dir}"/"{$foldername}
            return 0
        end
    end

    # Delete the existing install and move the new one over
    echo "Installing" $new_version
    command touch {$NVIM_INSTALL_PATH}"/sentinel"
    command rm -rf {$NVIM_INSTALL_PATH}"/"*
    command mv {$tmp_dir}"/"{$foldername}"/"* $NVIM_INSTALL_PATH

    # Cleanup
    command rm -r {$tmp_dir}"/"{$foldername}
end

# Prerequisites:
#   macOS: `brew install ninja libtool automake cmake pkg-config gettext`
#   linux: `sudo apt install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip`

function _nvim_nightly_compile --description "Compile the Nightly version of Neovim"
    _setup
    if test $status -ne 0
        return $status
    end

    # Download the archive to a temp directory
    set url "https://github.com/neovim/neovim/archive/nightly.tar.gz"
    set tmp_dir (mktemp -d)
    set tmp_path {$tmp_dir}"/neovim-nightly.tar.gz"
    echo "Downloading" $url "to" $tmp_path
    command curl -L --url $url --output $tmp_path

    # Extract the archive
    command tar xzvf $tmp_path -C $tmp_dir
    command rm $tmp_path

    # Build
    pushd {$tmp_dir}"/neovim-nightly"
    command echo "Building in " (pwd)
    command make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$NVIM_INSTALL_PATH"
    command make install
    popd

    # Cleanup
    command rm -rf {$tmp_dir}
end

function _setup
    # Create install path if needed
    if not test -e $NVIM_INSTALL_PATH
        echo "Creating install folder"
        command sudo mkdir -p $NVIM_INSTALL_PATH
        command sudo chown $USER $NVIM_INSTALL_PATH
    end

    # Make sure it's a folder with the right permissions
    if not test -e $NVIM_INSTALL_PATH; or not test -d $NVIM_INSTALL_PATH; or not test -O $NVIM_INSTALL_PATH
        echo "Make sure that" $NVIM_INSTALL_PATH "is a directory and is owned by" $USER
        return 1
    end
end
