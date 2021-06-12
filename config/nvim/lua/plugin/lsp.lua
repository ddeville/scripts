local nvim_lsp = require("lspconfig")
local lsp_status = require("lsp-status")

local function setup_client(name, config)
  config.capabilities = vim.tbl_deep_extend("force", lsp_status.capabilities, config.capabilities or {})

  local custom_on_attach = config.on_attach
  config.on_attach = function(client, bufnr)
    lsp_status.on_attach(client)

    local function set_keymap(mode, key, cmd)
      vim.api.nvim_buf_set_keymap(bufnr, mode, key, cmd, { noremap = true, silent = true })
    end
    set_keymap("n", "gd",         "<cmd>lua vim.lsp.buf.definition()<CR>")
    set_keymap("n", "gr",         "<cmd>lua vim.lsp.buf.references()<CR>")
    set_keymap("n", "gi",         "<cmd>lua vim.lsp.buf.implementation()<CR>")
    set_keymap("n", "gy",         "<cmd>lua vim.lsp.buf.type_definition()<CR>")
    set_keymap("n", "K",          "<cmd>lua vim.lsp.buf.hover()<CR>")
    set_keymap("n", "<C-k>",      "<cmd>lua vim.lsp.buf.signature_help()<CR>")
    set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>")
    set_keymap("n", "<leader>a",  "<cmd>lua vim.lsp.buf.code_action()<CR>")
    set_keymap("n", "<leader>e",  "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics({ focusable = false })<CR>")
    set_keymap("n", "<leader>q",  "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>")
    set_keymap("n", "[g",         "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>")
    set_keymap("n", "]g",         "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>")

    -- Invoke the custom `on_attach` function for the client, if needed
    if custom_on_attach then
      custom_on_attach(client, bufnr)
    end
  end

  nvim_lsp[name].setup(config)
end

setup_client("rust_analyzer", {
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
        enable = true;
      };
    };
  };
  capabilities = {
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
  };
})

setup_client("gopls", {
  cmd = { "gopls", "serve" };
  root_dir = function(fname)
    local mod = nvim_lsp.util.root_pattern("go.mod")(fname)
    if mod ~= nil then
      return mod
    end
    -- Pick the nearest GOPATH by default so that we don't create a million gopls instances
    local gopath = os.getenv("GOPATH") or ""
    for path in (gopath..":"):gmatch("(.-):") do
      if nvim_lsp.util.path.is_descendant(path, fname) then
        return path
      end
    end
    return nvim_lsp.util.root_pattern(".git")(fname)
  end;
  capabilities = lsp_status.capabilities;
})

-- TODO(damien): Fix this but right now it's spinning at 100% for hours on rSERVER...
-- setup_client("pyright", {})

setup_client("tsserver", {})

setup_client("clangd", {})

setup_client("sourcekit", {
  -- We use clangd for C/CPP/Objc
  filetypes = { "swift" };
})

setup_client("sumneko_lua", {
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

-- Setup diagnostics
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

-- Setup inlay hints for Rust, this needs to be aggressively refetched.
vim.api.nvim_command([[
autocmd BufEnter,BufWinEnter,BufWritePost,InsertLeave,TabEnter *.rs lua
require'lsp_extensions'.inlay_hints{
  highlight = "SpecialComment";
  prefix = " ▶ ";
  aligned = false;
  only_current_line = false;
  enabled = { "TypeHint", "ChainingHint" };
}
]])

-- Add support for reporting LSP progress in the ligthline (see `LspStatus` in vimrc)
lsp_status.register_progress()

local function status_message()
  if #vim.lsp.buf_get_clients(0) > 0 then
    local msg = lsp_status.status_progress()
    -- Try to prevent the status message from overflowing and thus moving all status items to the left.
    local space = vim.fn.winwidth(0) - 70
    if #msg > space then
      msg = string.sub(msg, 1, space)
    end
    return msg
  else
    return ""
  end
end

-- Display an indicator in the sign column when a code action is available
vim.fn.sign_define("LightBulbSign", { text = "▶", texthl = "LspDiagnosticsDefaultInformation" })
vim.api.nvim_command("autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()")

local M = {
  status_message = status_message;
}

return M
