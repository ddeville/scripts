set -gx EDITOR vi
set -gx CLICOLOR 1
set -gx TERM xterm-256color

set -gx GREP_OPTIONS "--color=auto"
set -gx LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

set -gx fish_color_autosuggestion 969896
set -gx fish_color_command b294bb
set -gx fish_color_comment f0c674
set -gx fish_color_cwd b5bd68
set -gx fish_color_cwd_root red
set -gx fish_color_end b294bb
set -gx fish_color_error cc6666
set -gx fish_color_escape 8abeb7
set -gx fish_color_history_current cyan
set -gx fish_color_host \x2do\x1ecyan
set -gx fish_color_match 8abeb7
set -gx fish_color_normal c5c8c6
set -gx fish_color_operator 8abeb7
set -gx fish_color_param 81a2be
set -gx fish_color_quote b5bd68
set -gx fish_color_redirection 8abeb7
set -gx fish_color_search_match b294bb
set -gx fish_color_selection \x2d\x2dbackground\x3dpurple
set -gx fish_color_status red
set -gx fish_color_user \x2do\x1egreen
set -gx fish_color_valid_path \x2d\x2dunderline
set -gx fish_key_bindings fish_default_key_bindings
set -gx fish_pager_color_completion normal
set -gx fish_pager_color_description 555\x1eyellow
set -gx fish_pager_color_prefix cyan
set -gx fish_pager_color_progress cyan

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

set -x PATH $HOME/scripts/bin $PATH

if which rbenv > /dev/null
  set -x PATH $HOME/.rbenv/shims $PATH
  set -x PATH $HOME/.rbenv/versions/(cat $HOME/.rbenv/version)/bin $PATH
end

if test -e "$HOME/.cargo/bin"
   set -x PATH $HOME/.cargo/bin $PATH
end

if set -x XCODE (xcode-select --print-path)
   set -x PATH $XCODE/usr/bin $PATH
end

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

