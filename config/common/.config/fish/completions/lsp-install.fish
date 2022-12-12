set -l commands all rust-analyzer clangd gopls tsserver pyright yaml sumneko_lua
complete -c lsp-install -f -a "$commands"
