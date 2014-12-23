alias ll="ls -lahL"
alias con="tail -40 -f /var/log/system.log"
alias topc="top -o cpu"
alias topm="top -o mem"
alias kd="killall Dock"
alias kdns="sudo killall -HUP mDNSResponder"

export EDITOR="vi"
export CLICOLOR=1
export GREP_OPTIONS='--color=auto'
export XCODE="`xcode-select --print-path`"
export PATH="$HOME/scripts/bin:$XCODE/Tools:/usr/local/bin:$PATH"

