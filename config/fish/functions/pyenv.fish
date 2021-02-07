function pyenv
    set command $argv[1]
    set -e argv[1]

    switch "$command"
    case rehash shell
        source (pyenv "sh-$command" $argv|psub)
    case install
        if test (uname) = "Darwin"
            # YouCompleteMe requires Python built with framework enabled
            set -gx PYTHON_CONFIGURE_OPTS "--enable-framework"
            echo "Note: Building Python with `--enable-framework` (see ~/.config/fish/functions/pyenv.fish for more info)"
            # Homebrew doesn't add symlinks for openssl on macOS since they already
            # install LibreSSL and they'd conflict.
            # Since building Python requires OpenSSL let's add these paths.
            if test -e "/opt/homebrew/opt/openssl"
                set -gx LDFLAGS "-L/opt/homebrew/opt/openssl/lib"
                set -gx CPPFLAGS "-I/opt/homebrew/opt/openssl/include"
                echo "Note: Adding Homebrew OpenSSL in /opt/homebrew/opt/openssl to compile flags (see ~/.config/fish/functions/pyenv.fish for more info)"
            else if test -e "/usr/local/opt/openssl"
                set -gx LDFLAGS "-L/usr/local/opt/openssl/lib"
                set -gx CPPFLAGS "-I/usr/local/opt/openssl/include"
                echo "Note: Adding Homebrew OpenSSL in /use/local/opt/openssl to compile flags (see ~/.config/fish/functions/pyenv.fish for more info)"
            else
                echo "Note: OpenSSL is not installed with Homebrew, building Python will likely fail"
            end
        end
        command pyenv "$command" $argv
    case '*'
        command pyenv "$command" $argv
    end
end
