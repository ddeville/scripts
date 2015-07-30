set -Ux PATH $HOME/scripts/bin $PATH
set -Ux PATH $XCODE/Tools:/usr/local/bin $PATH

set -Ux EDITOR vi
set -Ux CLICOLOR 1
set -Ux GREP_OPTIONS "--color=auto"
set -Ux XCODE `xcode-select --print-path`
set -Ux LSCOLORS gxfxbEaEBxxEhEhBaDaCaD

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

alias ll "ls -lahL"
alias oo "open ."
alias con "tail -40 -f /var/log/system.log"
alias topc "top -o cpu"
alias topm "top -o mem"
alias kd "killall Dock"
alias kdns "sudo killall -HUP mDNSResponder"
