set -l commands all rust-analyzer clangd gopls tsserver pyright sumneko_lua
complete -c lsp_install -f -a "$commands"
