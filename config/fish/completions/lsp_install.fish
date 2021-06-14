set -l commands all rust-analyzer clangd gopls tsserver pyright sumneko_lua
complete -c lsp_install -f
complete -c lsp_install -a "$commands"
