set -l commands prebuilt compile
complete -c nvim_nightly_install -f -n "not __fish_seen_subcommand_from $command" -a "$commands"
