local nvim_lsp = require('lspconfig')
local cmp_nvim_lsp = require('cmp_nvim_lsp')
local fidget = require('fidget')

local underline = { underline = true }

-- NOTE: We should be using the `LspDiagnostics*` variants but it seems like the `base16-vim` plugin
-- uses the `Diagnostic*` versions so let's set both.

vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsVirtualTextError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsSignError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsUnderlineError', { fg = 'Red', ctermfg = 'Red', cterm = underline })

vim.api.nvim_set_hl(0, 'DiagnosticDefaultError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticSignError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { fg = 'Red', ctermfg = 'Red', cterm = underline })

vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultWarning', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsVirtualTextWarning', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsSignWarning', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsUnderlineWarning', { fg = 'Yellow', ctermfg = 'Yellow', cterm = underline })

vim.api.nvim_set_hl(0, 'DiagnosticDefaultWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticSignWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { fg = 'Yellow', ctermfg = 'Yellow', cterm = underline })

vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultInformation', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsVirtualTextInformation', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsSignInformation', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsUnderlineInformation', { fg = 'White', ctermfg = 'White', cterm = underline })

vim.api.nvim_set_hl(0, 'DiagnosticDefaultInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticSignInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { fg = 'White', ctermfg = 'White', cterm = underline })

vim.api.nvim_set_hl(0, 'LspDiagnosticsDefaultHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsVirtualTextHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsSignHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'LspDiagnosticsUnderlineHint', { fg = 'Gray', ctermfg = 'Gray', cterm = underline })

vim.api.nvim_set_hl(0, 'DiagnosticDefaultHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticSignHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { fg = 'Gray', ctermfg = 'Gray', cterm = underline })

vim.fn.sign_define('LspDiagnosticsSignError', { text = 'E', texthl = 'LspDiagnosticsDefaultError' })
vim.fn.sign_define('LspDiagnosticsSignWarning', { text = 'W', texthl = 'LspDiagnosticsDefaultWarning' })
vim.fn.sign_define('LspDiagnosticsSignInformation', { text = 'I', texthl = 'LspDiagnosticsDefaultInformation' })
vim.fn.sign_define('LspDiagnosticsSignHint', { text = 'H', texthl = 'LspDiagnosticsDefaultHint' })

vim.fn.sign_define('DiagnosticSignError', { text = 'E', texthl = 'LspDiagnosticsDefaultError' })
vim.fn.sign_define('DiagnosticSignWarn', { text = 'W', texthl = 'LspDiagnosticsDefaultWarning' })
vim.fn.sign_define('DiagnosticSignInfo', { text = 'I', texthl = 'LspDiagnosticsDefaultInformation' })
vim.fn.sign_define('DiagnosticSignHint', { text = 'H', texthl = 'LspDiagnosticsDefaultHint' })

local function setup_client(name, config)
  config.capabilities =
    vim.tbl_deep_extend('force', config.capabilities or {}, vim.lsp.protocol.make_client_capabilities())
  config.capabilities = cmp_nvim_lsp.default_capabilities(config.capabilities)

  local custom_on_attach = config.on_attach
  config.on_attach = function(client, bufnr)
    local function set_keymap(key, fn)
      vim.api.nvim_buf_set_keymap(bufnr, 'n', key, '', { noremap = true, silent = true, callback = fn })
    end
    set_keymap('gd', vim.lsp.buf.definition)
    set_keymap('gr', vim.lsp.buf.references)
    set_keymap('gi', vim.lsp.buf.implementation)
    set_keymap('gy', vim.lsp.buf.type_definition)
    set_keymap('K', vim.lsp.buf.hover)
    set_keymap('<C-k>', vim.lsp.buf.signature_help)
    set_keymap('<leader>rn', vim.lsp.buf.rename)
    set_keymap('<leader>a', vim.lsp.buf.code_action)
    set_keymap('<leader>e', vim.diagnostic.open_float)
    set_keymap('<leader>q', vim.diagnostic.set_loclist)
    set_keymap('[g', vim.diagnostic.goto_prev)
    set_keymap(']g', vim.diagnostic.goto_next)

    -- Invoke the custom `on_attach` function for the client, if needed
    if custom_on_attach then
      custom_on_attach(client, bufnr)
    end
  end

  nvim_lsp[name].setup(config)
end

setup_client('rust_analyzer', {
  root_dir = function(fname)
    local cargo_crate_dir = nvim_lsp.util.root_pattern('Cargo.toml')(fname)
    -- Make sure that we run `cargo metadata` in the current project dir
    -- rather that the dir from which nvim was initially launched.
    local cmd = 'cargo metadata --no-deps --format-version 1'
    if cargo_crate_dir ~= nil then
      cmd = cmd .. ' --manifest-path ' .. nvim_lsp.util.path.join(cargo_crate_dir, 'Cargo.toml')
    end
    local cargo_metadata = vim.fn.system(cmd)
    local cargo_workspace_dir = nil
    if vim.v.shell_error == 0 then
      cargo_workspace_dir = vim.fn.json_decode(cargo_metadata)['workspace_root']
    end
    -- Order of preference:
    --   * Current workspace Cargo.toml
    --   * Current crate Cargo.toml
    --   * Rust project root (for non Cargo projects)
    --   * Current git repository
    return cargo_workspace_dir
      or cargo_crate_dir
      or nvim_lsp.util.root_pattern('rust-project.json')(fname)
      or nvim_lsp.util.find_git_ancestor(fname)
  end,
  settings = {
    ['rust-analyzer'] = {
      checkOnSave = {
        enable = true,
        -- Build out of tree so that we don't cause cargo lock contention
        extraArgs = { '--target-dir', '/tmp/rust-analyzer-check' },
      },
      cargo = {
        autoreload = true,
      },
      procMacro = {
        enable = true,
      },
    },
  },
  capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          -- We need snippets for compe to fully support rust-analyzer magic
          snippetSupport = true,
          resolveSupport = {
            properties = {
              'documentation',
              'detail',
              'additionalTextEdits',
            },
          },
        },
      },
    },
  },
})

setup_client('gopls', {
  cmd = { 'gopls', 'serve' },
  filetypes = { 'go', 'gomod' },
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
  root_dir = function(fname)
    local mod = nvim_lsp.util.root_pattern('go.mod')(fname)
    if mod ~= nil then
      return mod
    end
    -- Pick the nearest GOPATH by default so that we don't create a million gopls instances
    local gopath = os.getenv('GOPATH') or ''
    for path in (gopath .. ':'):gmatch('(.-):') do
      if nvim_lsp.util.path.is_descendant(path, fname) then
        return path
      end
    end
    return nvim_lsp.util.root_pattern('.git')(fname)
  end,
})

setup_client('pyright', {
  root_dir = function(fname)
    local root_files = {
      'pyproject.toml',
      'pyrightconfig.json',
      '.git',
      -- In theory we should also have the following but oai/api uses several packages but needs
      -- to be a single python project...
      --
      -- 'setup.py',
      -- 'setup.cfg',
      -- 'requirements.txt',
      -- 'Pipfile',
    }
    return nvim_lsp.util.root_pattern(unpack(root_files))(fname)
  end,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = 'workspace',
        typeCheckingMode = 'basic',
        useLibraryCodeForTypes = true,
      },
      venvPath = (function()
        local pyenv_root = os.getenv('PYENV_ROOT')
        if pyenv_root ~= nil then
          return pyenv_root .. '/versions'
        else
          return nil
        end
      end)(),
    },
  },
})

setup_client('tsserver', {})

-- TODO: Add schemas for k8s (and others) https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
setup_client('yamlls', {})

setup_client('terraformls', {})

setup_client('clangd', {})

setup_client('sourcekit', {
  -- We use clangd for C/CPP/Objc
  filetypes = { 'swift' },
})

setup_client('sumneko_lua', {
  cmd = { '/opt/lsp/bin/lua-language-server' },
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        path = vim.list_extend(vim.split(package.path, ';'), { 'lua/?.lua', 'lua/?/init.lua' }),
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { 'vim' },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = {
          [vim.fn.expand('$VIMRUNTIME/lua')] = true,
          [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
        },
      },
      telemetry = {
        enable = false,
      },
    },
  },
})

-- Setup diagnostics
vim.lsp.handlers['textDocument/publishDiagnostics'] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  signs = true,
  underline = true,
  virtual_text = {
    spacing = 4,
    severity_limit = 'Hint', -- Basically show all messages
  },
  update_in_insert = false,
})

-- LSP Status
fidget.setup({
  text = {
    spinner = 'bouncing_bar',
  },
})

-- Display an indicator in the sign column when a code action is available
vim.fn.sign_define('LightBulbSign', { text = '▶', texthl = 'LspDiagnosticsDefaultInformation' })
vim.api.nvim_create_autocmd('CursorHold,CursorHoldI', {
  pattern = '*',
  callback = function(args)
    require('nvim-lightbulb').update_lightbulb()
  end,
})
