set -x EDITOR vi
set -x CLICOLOR 1
set -x GREP_OPTIONS "--color=auto"
set -x LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

set -x PATH $HOME/scripts/bin $PATH

if which rbenv > /dev/null
  set -x PATH $HOME/.rbenv/shims $PATH
  set -x PATH $HOME/.rbenv/versions/(cat $HOME/.rbenv/version)/bin $PATH
end

if test -e "$HOME/.cargo/bin"
   set -x PATH $HOME/.cargo/bin $PATH
end

if set -x XCODE (xcode-select --print-path)
   set -x PATH $XCODE/Tools:/usr/local/bin $PATH
end

set fish_greeting "
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
