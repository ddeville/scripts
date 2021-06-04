local nvim_lsp = require("lspconfig")

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

local set_keymaps = function(bufnr)
  local key_opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gd",         "<cmd>lua vim.lsp.buf.definition()<CR>",                   key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gr",         "<cmd>lua vim.lsp.buf.references()<CR>",                   key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gi",         "<cmd>lua vim.lsp.buf.implementation()<CR>",               key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gy",         "<cmd>lua vim.lsp.buf.type_definition()<CR>",              key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "K",          "<cmd>lua vim.lsp.buf.hover()<CR>",                        key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-k>",      "<cmd>lua vim.lsp.buf.signature_help()<CR>",               key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>",                       key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>a",  "<cmd>lua vim.lsp.buf.code_action()<CR>",                  key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>e",  "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>q",  "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>",           key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "[g",         "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>",             key_opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "]g",         "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>",             key_opts)
end

local generic_on_attach = function(client, bufnr)
  set_keymaps(bufnr)
end

nvim_lsp.rust_analyzer.setup({
  on_attach = generic_on_attach;
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
    ["rust-analyzer"] = {
      checkOnSave = {
        enable = true;
        -- Build out of tree so that we don't cause cargo lock contention
        extraArgs = { "--target-dir", "/tmp/rust-analyzer-check" };
      };
      procMacro = {
        -- Enabling proc-macro seems to make things slower, maybe reassess later
        enable = false;
      };
    };
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
  on_attach = generic_on_attach;
})

nvim_lsp.pyright.setup({
  on_attach = generic_on_attach;
})

nvim_lsp.tsserver.setup({
  on_attach = generic_on_attach;
})

nvim_lsp.clangd.setup({
  on_attach = generic_on_attach;
})

nvim_lsp.sourcekit.setup({
  on_attach = generic_on_attach;
})

nvim_lsp.sumneko_lua.setup({
  on_attach = generic_on_attach;
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
