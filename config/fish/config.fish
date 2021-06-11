set -gx EDITOR nvim
set -gx CLICOLOR 1
set -gx GREP_OPTIONS "--color=auto"
set -gx VIMINIT "source ~/.vim/vimrc"

# setup the base16 shell and source the colors
if status --is-interactive
    source "$HOME/.config/base16-shell/profile_helper.fish"
end

# setup the fish colorscheme (Tomorrow Night Bright from the fish web config)
set fish_color_autosuggestion 969896
set fish_color_cancel \x2dr
set fish_color_command b294bb
set fish_color_comment eab700
set fish_color_cwd green
set fish_color_cwd_root red
set fish_color_end b294bb
set fish_color_error cc6666
set fish_color_escape 00a6b2
set fish_color_history_current \x2d\x2dbold
set fish_color_host normal
set fish_color_match \x2d\x2dbackground\x3dbrblue
set fish_color_normal normal
set fish_color_operator 00a6b2
set fish_color_param 81a2be
set fish_color_quote b5bd68
set fish_color_redirection 8abeb7
set fish_color_search_match bryellow\x1e\x2d\x2dbackground\x3dbrblack
set fish_color_selection white\x1e\x2d\x2dbold\x1e\x2d\x2dbackground\x3dbrblack
set fish_color_user brgreen
set fish_color_valid_path \x2d\x2dunderline
set fish_pager_color_completion normal
set fish_pager_color_description B3A06D\x1eyellow
set fish_pager_color_prefix white\x1e\x2d\x2dbold\x1e\x2d\x2dunderline
set fish_pager_color_progress brwhite\x1e\x2d\x2dbackground\x3dcyan

# use the vim key bindings
set -gx fish_key_bindings fish_vi_key_bindings

set -gx fish_greeting "
     /\     /\\
    {  `---'  }
    {  O   O  }
    ~~>  V  <~~
     \  \|/  /
      `-----'____
      /     \    \_
     {       }\  )_\_   _
     |  \_/  |/ /  \_\_/ )
      \__/  /(_/     \__/
        (__/

     Did I hear fish? Meow!
"

# clean up existing path before resourcing it so that starting tmux doesn't end
# up with duplicate entries in the path (and the default paths prepended to the
# front) - this is because this config file is loaded twice when starting tmux.
if test -e "/usr/libexec/path_helper"
    set PATH ""
    eval (/usr/libexec/path_helper -c)
end

# set up a list to collect the new path entries
set -l PATH_ENTRIES

# make sure that this is before anything in the path (it overwrite others)
if test -e "$HOME/.pyenv/bin"
    if test -e "$HOME/.pyenv/shims"
        set PATH_ENTRIES $PATH_ENTRIES "$HOME/.pyenv/shims"
    end
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.pyenv/bin"
    set -x PYENV_SHELL fish
end
# add the dropbox overrides before the rest (if this is a dropbox machine)
if test -e "/opt/dropbox-override/bin"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/dropbox-override/bin"
end
# we build neovim nightly in there
if test -e "/opt/nvim/nightly_compiled"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/nvim/nightly_compiled/bin"
end
# we install neovim nightly in there
if test -e "/opt/nvim/nightly_archived"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/nvim/nightly_archived/bin"
end
# we install the lsp server binaries in there
if test -e "/opt/lsp"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/lsp"
end
# brew install its stuff there on M1 macs
if test -e "/opt/homebrew/bin"
    set PATH_ENTRIES $PATH_ENTRIES "/opt/homebrew/bin"
end
# these can come afterwards, it's cool
if test -e "$HOME/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/bin"
end
if [ (uname -s) = "Darwin" ]; and test -e "$HOME/scripts/macos/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/scripts/macos/bin"
end
if test -e "$HOME/scripts/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/scripts/bin"
end
if test -e "$HOME/.cargo/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.cargo/bin"
end
if test -e "$HOME/.fzf/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.fzf/bin"
end
if which xcode-select > /dev/null 2>&1; and set XCODE (xcode-select --print-path); and test -e "$XCODE/usr/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$XCODE/usr/bin"
end
if test -e "/usr/local/sbin"
    set PATH_ENTRIES $PATH_ENTRIES "/usr/local/sbin"
end

# we can now set the new entries in front of the path
set -x PATH $PATH_ENTRIES $PATH

# GOPATH for Dropbox server code
if test -e "$HOME/src/server/go"
    if not set -q GOPATH || not contains "$HOME/src/server/go" "$GOPATH"
        set -x GOPATH $GOPATH "$HOME/src/server/go"
    end
end

# abbreviations
abbr -a cdd "cd .."
abbr -a oo "open ."
abbr -a con "tail -40 -f /var/log/system.log"
abbr -a topc "top -o cpu"
abbr -a topm "top -o mem"
abbr -a vpn "/opt/cisco/anyconnect/bin/vpn -s connect https://sjc.vpn.dropboxer.net"

# aliases
alias e="nvim"
alias realvim=(which vim)
alias vim="nvim"
alias ll="ls -lah"
alias gaa="git add .; and git ci"
alias gaaa="git add .; and git ci --amend"
alias adp="arc diff --preview"
alias adu="arc diff --update"

# ctrl-y to accept autocomplete suggestion
bind -M insert \cy accept-autosuggestion

# setup `fzf`
set -x FZF_TMUX 0
set -x FZF_DEFAULT_OPTS "--height 40% --border --tabstop=4"
set -x FZF_DEFAULT_COMMAND "fd --exclude .git --hidden --color=never"
set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -x FZF_ALT_C_COMMAND "fd --type d --exclude .git --hidden --color=never"
# alt-c doesn't work on macos so rather than tweaking the iterm settings bind it
bind -M insert "ç" fzf-cd-widget
