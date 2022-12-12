set -l commands all rust-analyzer clangd gopls tsserver pyright yamlls terraform-ls sumneko_lua
complete -c lsp-install -f -a "$commands"
