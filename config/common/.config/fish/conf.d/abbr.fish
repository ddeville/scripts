alias cdd "cd .."
alias ll "eza --long --all"
alias tree "eza --tree --level=3 --all"

alias o open
alias oo "open ."
alias t 'mkdir -p /tmp/scratch; and cd (mktemp --directory --tmpdir=/tmp/scratch (string split "/" $PWD --right --max=1 --fields=2).XXXXX)'

alias topc "top -o cpu"
alias topm "top -o mem"

alias g git
alias gaa "git add -A; and git ci"
alias gaaa "git add -A; and git ci --amend --no-edit"
alias gaau "git add -A; and git cu"
alias gcm "git co master"
alias grm "git rebase master"
alias grc "git rebase --continue"
alias gra "git rebase --abort"
alias gcb 'function _gcb; git checkout -b damien/$argv[1]; end; _gcb'

alias e nvim
alias tf terraform
alias py "uv run python"
