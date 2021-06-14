set -l commands install compile
complete -c nvim_nightly -f -n "not __fish_seen_subcommand_from $command" -a "$commands"
