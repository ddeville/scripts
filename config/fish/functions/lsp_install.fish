function lsp_install --description "Install various LSP server for Neovim"
    set install_path "/opt/nvim/lsp/bin"

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

    rust_analyzer $install_path
end

function rust_analyzer
    set install_path $argv[1]

    # Get the download URL for the latest package for the current platform
    if test (uname) = "Darwin"
        if test (uname -m) = "arm64"
            set filename "rust-analyzer-aarch64-apple-darwin"
        else
            set filename "rust-analyzer-x86_64-apple-darwin"
        end
    else if test (uname) = "Linux"
        set filename "rust-analyzer-x86_64-unknown-linux-gnu"
        set foldername "nvim-linux64"
    else
        echo "Unsupported platform:" (uname)
        return 1
    end
    set url "https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/"{$filename}".gz"

    # Download the archive to a temp directory
    set tmp_dir (mktemp -d)
    set tmp_path {$tmp_dir}"/"{$filename}".gz"
    echo "Downloading" $url "to" $tmp_path
    command curl -L --url $url --output $tmp_path

    # Extract the archive to output dir
    command gzip -d $tmp_path
    command mv $tmp_dir"/"{$filename} $install_path"/rust-analyzer"
    command chmod +x $install_path"/rust-analyzer"
end
