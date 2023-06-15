set -l commands prebuilt compile uninstall
complete -c nvim-nightly-install -f -n "not __fish_seen_subcommand_from $command" -a "$commands"
