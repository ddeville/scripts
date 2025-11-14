alias cdd "cd .."
alias ll "eza --long --all"
alias tree "eza --tree --level=3 --all"

alias o open
alias oo "open ."
alias t 'mkdir -p /tmp/scratch; and cd (mktemp --directory --tmpdir=/tmp/scratch (string split "/" $PWD --right --max=1 --fields=2).XXXXX)'

alias topc "top -o cpu"
alias topm "top -o mem"

alias e nvim
alias tf terraform
alias py "uv run python"
