# Prerequisites:
#   macOS: `brew install ninja libtool automake cmake pkg-config gettext`
#   linux: `sudo apt install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip`

function nvim_nightly_compile --description "Install the Nightly version of Neovim"
    set install_path "/opt/nvim/nightly_compiled"

    # Create install path if needed
    if not test -e $install_path
        echo "Creating install folder"
        command sudo mkdir -p $install_path
        command sudo chown $USER $install_path
    end

    # Make sure it's a folder with the right permissions
    if not test -e $install_path; or not test -d $install_path; or not test -O $install_path
        echo "Make sure that" $install_path "is a directory and is owned by" $USER
        return 1
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
    command make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$install_path"
    command make install
    popd

    # Cleanup
    command rm -rf {$tmp_dir}
end
