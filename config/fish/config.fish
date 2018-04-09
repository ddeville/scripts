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

# make sure that these are before anything in the path (they overwrite others)
if test -e "$HOME/.pyenv/bin"
    set -x fish_user_paths $HOME/.pyenv/bin $fish_user_paths
    set -x PYENV_SHELL fish
    if test -e "$HOME/.pyenv/shims"
        set -x fish_user_paths $HOME/.pyenv/shims $fish_user_paths
    end
end
# add the dropbox overrides before the rest (if this is a dropbox machine)
if test -e "/opt/dropbox-override/bin"
    set -x fish_user_paths $fish_user_paths "/opt/dropbox-override/bin"
end
# these can come afterwards, it's cool
if [ (uname -s) = "Darwin" ]; and test -e "$HOME/scripts/macos/bin"
  set -x fish_user_paths $fish_user_paths $HOME/scripts/macos/bin
end
if test -e "$HOME/scripts/bin"
    set -x fish_user_paths $fish_user_paths $HOME/scripts/bin
end
if test -e "$HOME/.cargo/bin"
   set -x fish_user_paths $fish_user_paths $HOME/.cargo/bin
end
if which xcode-select > /dev/null; and set -x XCODE (xcode-select --print-path); and test -e $XCODE
   set -x fish_user_paths $fish_user_paths $XCODE/usr/bin
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
