# aliases
alias e nvim
alias realvim (which vim)
alias vim nvim
alias ll "eza --long --all"
alias tree "eza --tree --level=3"
alias gaa "git add -A; and git ci"
alias gaaa "git add -A; and git ci --amend --no-edit"
alias gaau "git add -A; and git cu"
alias gcm "git co master"
alias grm "git rebase master"
alias oo "open ."
alias tf terraform

# abbreviations
abbr -a -g cdd "cd .."
abbr -a -g con "tail -40 -f /var/log/system.log"
abbr -a -g topc "top -o cpu"
abbr -a -g topm "top -o mem"
