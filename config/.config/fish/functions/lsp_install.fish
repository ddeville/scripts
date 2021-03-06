# NOTE: Remember to add to completions when adding a new server type

function lsp_install --description "Install various LSP servers for Neovim"
    if test -d $argv
        echo "Available servers:"
        echo "  * rust-analyzer"
        echo "  * clangd"
        echo "  * gopls"
        echo "  * tsserver"
        echo "  * pyright"
        echo "  * sumneko_lua"
        return 1
    end

    # If `all` was passed install all
    if contains all $argv
        set install_all 1
    end

    set install_path "/opt/lsp"

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

    command mkdir -p $install_path"/bin"

    pushd $install_path


    # Install!

    if contains rust-analyzer $argv || set -q install_all
        _rust_analyzer
    end
    if contains clangd $argv || set -q install_all
        _clangd
    end
    if contains gopls $argv || set -q install_all
        _gopls
    end
    if contains tsserver $argv || set -q install_all
        _tsserver
    end
    if contains pyright $argv || set -q install_all
        _pyright
    end
    if contains sumneko_lua $argv || set -q install_all
        _sumneko_lua
    end

    popd $install_path
end

function _rust_analyzer
    echo "Installing rust-analyzer"

    set foldername "_rust-analyzer"
    set linkname "bin/rust-analyzer"

    if test -e $foldername
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    if test (uname) = "Darwin"
        if test (uname -m) = "arm64"
            set filename "rust-analyzer-aarch64-apple-darwin"
        else
            set filename "rust-analyzer-x86_64-apple-darwin"
        end
    else if test (uname) = "Linux"
        set filename "rust-analyzer-x86_64-unknown-linux-gnu"
    else
        echo "Unsupported platform:" (uname)
        return 1
    end
    set url "https://github.com/rust-analyzer/rust-analyzer/releases/latest/download/"{$filename}".gz"

    set archive_path $filename".gz"
    echo "Downloading" $url "to" $archive_path
    command curl -L --url $url --output $archive_path

    command gzip -d $archive_path
    command mv $filename rust-analyzer
    command chmod +x rust-analyzer

    popd $foldername

    command ln -s ../$foldername/rust-analyzer $linkname
end

function _clangd
    echo "Installing clangd"

    set foldername "_clangd"
    set linkname "bin/clangd"

    if test -e $foldername
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    if test (uname) = "Darwin"
        set platform_name "mac"
    else if test (uname) = "Linux"
        set platform_name "linux"
    else
        echo "Unsupported platform:" (uname)
        return 1
    end

    set version_url "https://api.github.com/repos/clangd/clangd/releases/latest"
    set version_name (curl $version_url | jq --raw-output '.name')
    set url "https://github.com/clangd/clangd/releases/download/"$version_name"/clangd-"$platform_name"-"$version_name".zip"

    set archive_path "clangd.zip"
    echo "Downloading" $url "to" $archive_path
    command curl -L --url $url --output $archive_path

    command unzip -q $archive_path
    command rm $archive_path

    popd $foldername

    set bin_path $foldername"/clangd_"$version_name"/bin/clangd"
    command chmod +x $bin_path

    command ln -s ../$bin_path  $linkname
end

function _gopls
    echo "Installing gopls"

    if not type -q go
        echo "The gopls language server requires Go to be installed"
        return 1
    end

    set foldername "_gopls"
    set linkname "bin/gopls"

    if test -e $foldername
        chmod -R 700 $foldername  # some go files in `pkg/` are not writable...
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    set -x GOPATH (command pwd)
    set -x GOBIN (command pwd)
    set -x GO111MODULE on
    go get -v golang.org/x/tools/gopls
    go clean -modcache

    popd $foldername

    command ln -s ../$foldername/gopls $linkname
end

function _tsserver
    echo "Installing tsserver"

    if not type -q npm
        echo "The tsserver language server requires Node to be installed"
        return 1
    end

    set foldername "_tsserver"
    set linkname "bin/typescript-language-server"

    if test -e $foldername
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    npm init -y --scope=lsp
    npm install typescript-language-server@latest typescript@latest

    popd $foldername

    command ln -s ../$foldername/node_modules/.bin/typescript-language-server $linkname
end

function _pyright
    echo "Installing pyright"

    if not type -q npm
        echo "The pyright language server requires Node to be installed"
        return 1
    end

    set foldername "_pyright"
    set linkname "bin/pyright-langserver"

    if test -e $foldername
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    npm init -y --scope=lsp
    npm install pyright@latest

    popd $foldername

    command ln -s ../$foldername/node_modules/.bin/pyright-langserver $linkname
end

function _sumneko_lua
    echo "Installing sumneko_lua"

    if not type -q ninja
        echo "The numseko_lua language server requires Ninja to be installed"
        return 1
    end

    set foldername "_lua"
    set linkname "bin/lua-language-server"

    if test -e $foldername
        command rm -rf $foldername
    end
    if test -L $linkname
        command rm $linkname
    end

    command mkdir $foldername

    pushd $foldername

    if test (uname) = "Darwin"
        set ninja_file "macos.ninja"
        set bin_dir "macOS"
    else if test (uname) = "Linux"
        set ninja_file "linux.ninja"
        set bin_dir "Linux"
    else
        echo "Unsupported platform:" (uname)
        return 1
    end

    # We assume that the first tag is the latest, an assumption that the GH API
    # also makes...
    set tags_url "https://api.github.com/repos/sumneko/lua-language-server/tags"
    set tag_name (curl $tags_url | jq --raw-output '.[0].name')

    command git clone -b $tag_name "https://github.com/sumneko/lua-language-server.git"

    pushd "lua-language-server"

    command git submodule update --init --recursive

    pushd "3rd/luamake"
    command ninja -f compile/ninja/$ninja_file
    popd "3rd/luamake"

    ./3rd/luamake/luamake rebuild

    popd "lua-language-server"

    set curpath (pwd)

    command echo >lua "#!/bin/sh
    "$curpath"/lua-language-server/bin/"$bin_dir"/lua-language-server -E "$curpath"/lua-language-server/main.lua"
    command chmod +x lua

    popd $foldername

    command ln -s ../$foldername/lua $linkname
end
