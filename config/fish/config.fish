set -gx EDITOR vim
set -gx CLICOLOR 1
set -gx TERM xterm-256color

set -gx GREP_OPTIONS "--color=auto"
set -gx LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

# fish colors
set -gx fish_color_autosuggestion 586e75
set -gx fish_color_command b294bb
set -gx fish_color_comment 586e75
set -gx fish_color_end 268bd2
set -gx fish_color_error dc322f
set -gx fish_color_param 839496
set -gx fish_color_quote 657b83
set -gx fish_color_redirection 6c71c4

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

# set up a list to collect the new path entries
set -l PATH_ENTRIES

# make sure that these are before anything in the path (they overwrite others)
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
# these can come afterwards, it's cool
if test -e "$HOME/.fzf/bin"
    set PATH_ENTRIES $PATH_ENTRIES "$HOME/.fzf/bin"
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
if which xcode-select > /dev/null; and set -x XCODE (xcode-select --print-path); and test -e $XCODE
    set PATH_ENTRIES $PATH_ENTRIES "$XCODE/usr/bin"
end

# make sure that we don't set the path if in tmux otherwise there will be
# duplicate entries in the path
if test -z $TMUX
    set -x PATH $PATH_ENTRIES $PATH
end

# abbreviations
abbr -a k "clear"
abbr -a ll "ls -lahL"
abbr -a oo "open ."
abbr -a gs "git status"
abbr -a gf "git difftool"
abbr -a ch "git log --oneline (get_git_remote_branch)..HEAD"
abbr -a chall "git log --branches  --not --remotes --simplify-by-decoration --decorate --oneline"
abbr -a con "tail -40 -f /var/log/system.log"
abbr -a topc "top -o cpu"
abbr -a topm "top -o mem"
abbr -a kd "killall Dock"
abbr -a mypy2 "time ./ci/mypy_all.sh -i --quick"
abbr -a mypy3 "time ./ci/mypy3_all.sh -i --quick"
abbr -a adp "arc diff --preview"

# setup `fzf`
set -x FZF_TMUX 0
set -x FZF_DEFAULT_OPTS "--height 40% --border --tabstop=4"
set -x FZF_ALT_C_COMMAND "find .\
                          -type d -name '.git' -prune -o\
                          -type d -name '__pycache__' -prune -o\
                          -type d -print\
                          | cut -d/ -f2-"

# setup `fzf` and `ag`
if type -q fzf; and type -q ag
    set -x FZF_DEFAULT_COMMAND 'git ls-files | ag -g ""'
    set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
end
