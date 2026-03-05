alias cdd "cd .."
alias ll "eza --long --all"
alias tree "eza --tree --level=3 --all"

alias o open
alias oo "open ."

alias topc "top -o cpu"
alias topm "top -o mem"

alias e nvim
alias tf terraform

# NOTE: Not an alias because it gets turned into a function that messes up stdin/stdout by introducing some buffering.
abbr jll "jl --color --max-field-length=0 --include-fields=name"
