set -gx EDITOR vi
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

# set the path
if test -e "$HOME/scripts/bin"
    set -x PATH $PATH $HOME/scripts/bin
end
if [ (uname -s) = "Darwin" ]; and test -e "$HOME/scripts/macos/bin"
  set -x PATH $PATH $HOME/scripts/macos/bin
end
if which xcode-select > /dev/null; and set -x XCODE (xcode-select --print-path)
   set -x PATH $PATH $XCODE/usr/bin
end
if which rbenv > /dev/null
  set -x PATH $PATH $HOME/.rbenv/shims
  set -x PATH $PATH $HOME/.rbenv/versions/(cat $HOME/.rbenv/version)/bin
end
if test -e "$HOME/.cargo/bin"
   set -x PATH $PATH $HOME/.cargo/bin
end

# abbreviations
abbr -a ll "ls -lahL"
abbr -a oo "open ."
abbr -a ss "subl --new-window"
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
