local function setup_lsp_client(name, config)
  -- Extend capabilities with nvim-cmp's default capabilities
  local lsp_capabilities = vim.lsp.protocol.make_client_capabilities()
  config.capabilities = vim.tbl_deep_extend('force', config.capabilities or {}, lsp_capabilities)
  config.capabilities = require('cmp_nvim_lsp').default_capabilities(config.capabilities)
  require('lspconfig')[name].setup(config)
end

local function setup_lsp()
  -- Disable LSP semantic tokens since we use treesitter for syntax highlighting anyway...
  -- (see https://www.reddit.com/r/neovim/comments/109vgtl/how_to_disable_highlight_from_lsp)
  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('LspDisableSemanticTokensProvider', {}),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      client.server_capabilities.semanticTokensProvider = nil
    end,
  })

  setup_lsp_client('rust_analyzer', {
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

  setup_lsp_client('gopls', {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
      },
    },
  })

  setup_lsp_client('pyright', {
    root_dir = function(fname)
      -- HACK: The API repo has a bunch of packages but a single pyrightconfig.json file...
      local api_path = '/Users/damien/code/api'
      if fname:sub(1, #api_path) == api_path then
        return api_path
      end
      return require('lspconfig.server_configurations.pyright').default_config.root_dir
    end,
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = 'workspace',
          typeCheckingMode = 'basic',
          useLibraryCodeForTypes = true,
          diagnosticSeverityOverrides = {
            reportMissingImports = false,
            reportMissingTypeStubs = false,
            reportPrivateImportUsage = false,
            reportGeneralTypeIssues = 'information',
            reportUnusedClass = 'warning',
            reportUnusedFunction = 'warning',
            reportDuplicateImport = 'warning',
            reportUntypedFunctionDecorator = 'warning',
            reportUntypedClassDecorator = 'warning',
            reportUntypedBaseClass = 'warning',
            reportUntypedNamedTuple = 'warning',
            reportTypeCommentUsage = 'warning',
            reportIncompatibleMethodOverride = 'warning',
            reportIncompatibleVariableOverride = 'warning',
            reportInconsistentConstructor = 'warning',
            reportUninitializedInstanceVariable = 'warning',
            reportUnnecessaryIsInstance = 'warning',
            reportUnnecessaryCast = 'warning',
            reportUnnecessaryComparison = 'warning',
            reportUnnecessaryContains = 'warning',
            reportUnnecessaryTypeIgnoreComment = 'warning',
          },
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

  setup_lsp_client('tsserver', {})

  setup_lsp_client('yamlls', {})

  setup_lsp_client('terraformls', {})

  setup_lsp_client('clangd', {
    -- Specifically omitting proto here
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  })

  setup_lsp_client('sourcekit', {
    -- We use clangd for C/CPP/Objc
    filetypes = { 'swift' },
  })

  setup_lsp_client('lua_ls', {
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

  setup_lsp_client('bashls', {})

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
end

return {
  {
    'neovim/nvim-lspconfig',
    config = setup_lsp,
    -- It is important for mason and mason-lspconfig's setup to have run before lspconfig's
    priority = 51,
    dependencies = {
      {
        'williamboman/mason-lspconfig.nvim',
        priority = 50,
        config = function()
          require('mason-lspconfig').setup({
            ensure_installed = {
              'bashls',
              'clangd',
              'gopls',
              'lua_ls',
              'pyright',
              'ruff_lsp',
              'rust_analyzer',
              'terraformls',
              'tsserver',
              'yamlls',
            },
            automatic_installation = true,
          })
        end,
      },
    },
  },
  {
    'j-hui/fidget.nvim',
    -- TODO(damien): Remove legacy tag once new version has been released https://github.com/j-hui/fidget.nvim
    tag = 'legacy',
    config = function()
      -- LSP Status
      require('fidget').setup({
        text = {
          spinner = 'bouncing_bar',
        },
        timer = {
          fidget_decay = 0,
          task_decay = 200,
        },
      })
    end,
  },
  {
    'kosayoda/nvim-lightbulb',
    config = function()
      -- Display an indicator in the sign column when a code action is available
      vim.fn.sign_define('LightBulbSign', { text = '▶', texthl = 'LspDiagnosticsDefaultInformation' })
      vim.api.nvim_create_autocmd('CursorHold,CursorHoldI', {
        pattern = '*',
        callback = function(args)
          require('nvim-lightbulb').update_lightbulb()
        end,
      })
    end,
  },
}
