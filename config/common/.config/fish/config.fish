set -gx CLICOLOR 1
set -gx EDITOR nvim

# Sometimes this is not set correctly if only the Xcode CLI tools are installed
if test (uname) = Darwin && ! test -n "$SDKROOT"
    set -gx SDKROOT (xcrun --sdk macosx --show-sdk-path)
end
