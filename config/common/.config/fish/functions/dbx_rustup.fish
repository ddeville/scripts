function dbx_rustup --description "Install the current rSERVER/desktop Rust version"
    set toolchain_path rust-toolchain
    if test -e $toolchain_path
        set toolchain (cat $toolchain_path)
        rustup toolchain add $toolchain
        rustup override set $toolchain
    else
        echo "You need to run this command in the desktop folder in your rSERVER repo!"
    end
end
