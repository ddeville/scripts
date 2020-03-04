function dbx_rustup --description "Install the current rCLIENT Rust version"
    set toolchain_path "rust-toolchain"
    if test -e $toolchain_path
        set toolchain (cat $toolchain_path)
        rustup toolchain add $toolchain
        rustup override set $toolchain
    else
        echo "You need to run this command in your client repo!"
    end
end
