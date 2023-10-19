function pyenv
    if not type -fq pyenv
        echo "pyenv is not installed, this is just a fish function wrapper!"
        return 1
    end

    set command $argv[1]
    set -e argv[1]

    switch "$command"
        case activate deactivate rehash shell
            source (pyenv "sh-$command" $argv|psub)
        case install
            set -gx PYTHON_CONFIGURE_OPTS "--enable-optimizations --with-lto --disable-shared"
            set -gx PYTHON_CFLAGS "-march=native -mtune=native"
            echo "Note: Building Python with optimization options (see ~/.config/fish/functions/pyenv.fish for more info)"

            if test (uname) = Darwin
                # Homebrew doesn't add symlinks for openssl on macOS since they already
                # install LibreSSL and they'd conflict.
                # Since building Python requires OpenSSL let's add these paths.
                if test -e /opt/homebrew/opt/openssl
                    set -gx LDFLAGS -L/opt/homebrew/opt/openssl/lib
                    set -gx CPPFLAGS -I/opt/homebrew/opt/openssl/include
                    echo "Note: Adding Homebrew OpenSSL in /opt/homebrew/opt/openssl to compile flags (see ~/.config/fish/functions/pyenv.fish for more info)"
                else if test -e /usr/local/opt/openssl
                    set -gx LDFLAGS -L/usr/local/opt/openssl/lib
                    set -gx CPPFLAGS -I/usr/local/opt/openssl/include
                    echo "Note: Adding Homebrew OpenSSL in /use/local/opt/openssl to compile flags (see ~/.config/fish/functions/pyenv.fish for more info)"
                else
                    echo "Note: OpenSSL is not installed with Homebrew, building Python will likely fail"
                end
                command pyenv "$command" $argv
            end
        case '*'
            command pyenv "$command" $argv
    end
end
