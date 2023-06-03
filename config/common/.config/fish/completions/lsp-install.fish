set -l commands all rust-analyzer clangd gopls tsserver pyright yamlls terraform-ls lua-ls bash-ls
complete -c lsp-install -f -a "$commands"
