local nvim_lsp = require('lspconfig')

local servers = { "rust_analyzer", "sourcekit", "clangd", "gopls", "pyright", "tsserver" }

local on_attach = function(client, bufnr)
  -- Diagnostic settings
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
      signs = true,
      underline = true,
      virtual_text = {
        spacing = 4,
        severity_limit = "Hint",  -- Basically show all messages
      },
      update_in_insert = false,
    }
  )

  -- Mappings.
  local key_opts = { noremap=true, silent=true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-j>", "<Cmd>lua vim.lsp.buf.definition()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", key_opts)

  -- Configure sign column
  vim.fn.sign_define("LspDiagnosticsSignError", { text = "E", texthl = "LspDiagnosticsDefaultError" })
  vim.fn.sign_define("LspDiagnosticsSignWarning", { text = "W", texthl = "LspDiagnosticsDefaultWarning" })
  vim.fn.sign_define("LspDiagnosticsSignInformation", { text = "I", texthl = "LspDiagnosticsDefaultInformation" })
  vim.fn.sign_define("LspDiagnosticsSignHint", { text = "H", texthl = "LspDiagnosticsDefaultHint" })

  -- Colorscheme for diagnostic messages
  -- Error in Red
  vim.api.nvim_command("highlight LspDiagnosticsDefaultError guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextError guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsSignError guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineError guifg=Red ctermfg=Red")
  -- Warning in Yellow
  vim.api.nvim_command("highlight LspDiagnosticsDefaultWarning guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextWarning guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsSignWarning guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineWarning guifg=Red ctermfg=Red")
  -- Info in White
  vim.api.nvim_command("highlight LspDiagnosticsDefaultInformation guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextInformation guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsSignInformation guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineInformation guifg=White ctermfg=White")
  -- Hint in Gray
  vim.api.nvim_command("highlight LspDiagnosticsDefaultHint guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextHint guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsSignHint guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineHint guifg=Gray ctermfg=Gray")
end

local extra_config = {
  rust_analyzer = {
    root_dir = nvim_lsp.util.root_pattern('rust-toolchain'),
  }
}

for _, lsp in ipairs(servers) do
  config = (extra_config[lsp] and extra_config[lsp] or {})
  config["on_attach"] = on_attach
  nvim_lsp[lsp].setup(config)
end
