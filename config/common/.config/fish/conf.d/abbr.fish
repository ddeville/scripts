# aliases
alias e "nvim"
alias realvim (which vim)
alias vim "nvim"
alias ll "exa --long --all"
alias tree "exa --tree --level=3"
alias gaa "git add .; and git ci"
alias gaaa "git add .; and git ci --amend --no-edit"
alias oo "open ."

# abbreviations
abbr -a -g cdd "cd .."
abbr -a -g con "tail -40 -f /var/log/system.log"
abbr -a -g topc "top -o cpu"
abbr -a -g topm "top -o mem"
abbr -a -g vpn "echo -e \"push\r\" | /opt/cisco/anyconnect/bin/vpn -s connect \"[Connect to nearest vpn]\""
