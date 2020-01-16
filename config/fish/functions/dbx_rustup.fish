function dbx_rustup
    set deps_path "deps/dependency_versions.bzl"
    if test -e $deps_path
        set nightly_version (cat $deps_path | grep RUSTC_VERSION|grep -oE '[0-9]{4}(-[0-9]{2}){2}')
        rustup toolchain add nightly-$nightly_version
        rustup override set nightly-$nightly_version
    else
        echo "You need to run this command in your client repo!"
    end
end
