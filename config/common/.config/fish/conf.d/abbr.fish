# aliases
alias e nvim
alias realvim (which vim)
alias vim nvim
alias ll "eza --long --all"
alias tree "eza --tree --level=3 --all"
alias g git
alias gaa "git add -A; and git ci"
alias gaaa "git add -A; and git ci --amend --no-edit"
alias gaau "git add -A; and git cu"
alias gcm "git co master"
alias grm "git rebase master"
alias grc "git rebase --continue"
alias gra "git rebase --abort"
alias o open
alias oo "open ."
alias t 'mkdir -p /tmp/scratch; and cd (mktemp --directory --tmpdir=/tmp/scratch (string split "/" $PWD --right --max=1 --fields=2).XXXXX)'
alias tf terraform

# abbreviations
abbr -a -g cdd "cd .."
abbr -a -g con "tail -40 -f /var/log/system.log"
abbr -a -g topc "top -o cpu"
abbr -a -g topm "top -o mem"
