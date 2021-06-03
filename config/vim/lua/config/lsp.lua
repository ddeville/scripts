local nvim_lsp = require("lspconfig")

local on_generic_client_attach = function(client, bufnr)
  -- Mappings.
  local key_opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gd",        "<cmd>lua vim.lsp.buf.definition()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gr",        "<cmd>lua vim.lsp.buf.references()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gi",        "<cmd>lua vim.lsp.buf.implementation()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gy",        "<cmd>lua vim.lsp.buf.type_definition()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "K",         "<cmd>lua vim.lsp.buf.hover()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-k>",     "<cmd>lua vim.lsp.buf.signature_help()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>a",  "<cmd>lua vim.lsp.buf.code_action()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>e",  "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<space>q",  "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "[g",        "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "]g",        "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", key_opts)

  -- Diagnostic settings
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics, {
      signs = true;
      underline = true;
      virtual_text = {
        spacing = 4;
        severity_limit = "Hint";  -- Basically show all messages
      };
      update_in_insert = false;
    }
  )

  -- Configure sign column for diagnostic messages
  vim.fn.sign_define("LspDiagnosticsSignError",       { text = "E", texthl = "LspDiagnosticsDefaultError" })
  vim.fn.sign_define("LspDiagnosticsSignWarning",     { text = "W", texthl = "LspDiagnosticsDefaultWarning" })
  vim.fn.sign_define("LspDiagnosticsSignInformation", { text = "I", texthl = "LspDiagnosticsDefaultInformation" })
  vim.fn.sign_define("LspDiagnosticsSignHint",        { text = "H", texthl = "LspDiagnosticsDefaultHint" })

  -- Colorscheme for diagnostic messages
  -- Error in Red
  vim.api.nvim_command("highlight LspDiagnosticsDefaultError            guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextError        guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsSignError               guifg=Red ctermfg=Red")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineError          guifg=Red ctermfg=Red")
  -- Warning in Yellow
  vim.api.nvim_command("highlight LspDiagnosticsDefaultWarning          guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextWarning      guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsSignWarning             guifg=Yellow ctermfg=Yellow")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineWarning        guifg=Red ctermfg=Red")
  -- Info in White
  vim.api.nvim_command("highlight LspDiagnosticsDefaultInformation      guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextInformation  guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsSignInformation         guifg=White ctermfg=White")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineInformation    guifg=White ctermfg=White")
  -- Hint in Gray
  vim.api.nvim_command("highlight LspDiagnosticsDefaultHint             guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsVirtualTextHint         guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsSignHint                guifg=Gray ctermfg=Gray")
  vim.api.nvim_command("highlight LspDiagnosticsUnderlineHint           guifg=Gray ctermfg=Gray")
end

nvim_lsp.rust_analyzer.setup({
  on_attach = on_generic_client_attach;
  root_dir = function(fname)
    local cargo_crate_dir = nvim_lsp.util.root_pattern("Cargo.toml")(fname)
    -- Make sure that we run `cargo metadata` in the current project dir
    -- rather that the dir from which nvim was initially launched.
    local cmd = "cargo metadata --no-deps --format-version 1"
    if cargo_crate_dir ~= nil then
      cmd = cmd .. " --manifest-path " .. nvim_lsp.util.path.join(cargo_crate_dir, "Cargo.toml")
    end
    local cargo_metadata = vim.fn.system(cmd)
    local cargo_workspace_dir = nil
    if vim.v.shell_error == 0 then
      cargo_workspace_dir = vim.fn.json_decode(cargo_metadata)["workspace_root"]
    end
    -- Order of preference:
    --   * Current workspace Cargo.toml
    --   * Current crate Cargo.toml
    --   * Rust project root (for non Cargo projects)
    --   * Current git repository
    return cargo_workspace_dir or
      cargo_crate_dir or
      nvim_lsp.util.root_pattern("rust-project.json")(fname) or
      nvim_lsp.util.find_git_ancestor(fname)
  end;
  settings = {
    ["rust-analyzer"] = {};
  };
  capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), {
    textDocument = {
      completion = {
        completionItem = {
          -- We need snippets for compe to fully support rust-analyzer magic
          snippetSupport = true;
          resolveSupport = {
            properties = {
              "documentation";
              "detail";
              "additionalTextEdits";
            };
          };
        };
      };
    };
  });
})

nvim_lsp.gopls.setup({
  on_attach = on_generic_client_attach;
})

nvim_lsp.pyright.setup({
  on_attach = on_generic_client_attach;
})

nvim_lsp.tsserver.setup({
  on_attach = on_generic_client_attach;
})

nvim_lsp.clangd.setup({
  on_attach = on_generic_client_attach;
})

nvim_lsp.sourcekit.setup({
  on_attach = on_generic_client_attach;
})

nvim_lsp.sumneko_lua.setup({
  on_attach = on_generic_client_attach;
  cmd = { "/opt/lsp/lua-language-server" };
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT";
        path = vim.list_extend(vim.split(package.path, ";"), { "lua/?.lua", "lua/?/init.lua" });
      };
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "vim" };
      };
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true;
          [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true;
        };
      };
      telemetry = {
        enable = false;
      };
    };
  };
})
