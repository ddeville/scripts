alias ll="ls -lahL"
alias con="tail -40 -f /var/log/system.log"
alias kd="killall Dock"
alias kdns="sudo killall -HUP mDNSResponder"

export EDITOR="vi"
export CLICOLOR=1
export GREP_OPTIONS='--color=auto'
export XCODE="`xcode-select --print-path`"
export PATH="$HOME/Scripts/scripts:$XCODE/Tools:/usr/local/bin:$PATH"

