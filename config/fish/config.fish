set -gx EDITOR nvim
set -gx CLICOLOR 1
set -gx GREP_OPTIONS "--color=auto"
set -gx VIMINIT "source ~/.vim/vimrc"

# XDG Base Directory
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_DATA_HOME "$HOME/.local/share"

source "$XDG_CONFIG_HOME/fish/config/colors.fish"
source "$XDG_CONFIG_HOME/fish/config/path.fish"
source "$XDG_CONFIG_HOME/fish/config/alias.fish"
source "$XDG_CONFIG_HOME/fish/config/bindings.fish"
