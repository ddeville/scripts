local function normalize_path(path)
  return (vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ':p')):gsub('/$', ''))
end

local servers = {
  bashls = {},

  clangd = {
    -- Specifically omitting proto here
    filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    -- See https://github.com/jose-elias-alvarez/null-ls.nvim/issues/428
    capabilities = { offsetEncoding = { 'utf-16' } },
  },

  gopls = {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
      },
    },
  },

  lua_ls = {
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
          library = vim.api.nvim_get_runtime_file('', true),
        },
        telemetry = {
          enable = false,
        },
      },
    },
  },

  ty = {
    capabilities = {
      workspace = {
        didChangeWatchedFiles = {
          -- Frequently leads to EMFILE in a large repo...
          dynamicRegistration = false,
        },
      },
    },
    root_dir = function(bufnr, on_dir)
      local root = vim.fs.root(bufnr, { 'ty.toml', 'pyproject.toml', 'setup.py', 'setup.cfg', 'requirements.txt' })
      local ty_root_blacklist = vim.tbl_map(
        normalize_path,
        vim.split(vim.env.NVIM_TY_ROOT_BLACKLIST or '', ':', { plain = true, trimempty = true })
      )
      if root and not vim.tbl_contains(ty_root_blacklist, normalize_path(root)) then
        on_dir(root)
      end
    end,
    settings = {},
  },

  rust_analyzer = {
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
            -- We need snippets for nvim-cmp to fully support rust-analyzer magic
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
  },

  sourcekit = {
    -- We use clangd for C/CPP/Objc
    filetypes = { 'swift' },
  },

  terraformls = {},

  -- TODO: Re-enable this but the switch from terraformls to ts_ls broke things...
  -- ts_ls = {},

  yamlls = {
    filetypes = { 'yaml' },
    settings = {
      yaml = {
        keyOrdering = false,
      },
    },
  },
}

-- This is a list of servers that are already installed on the machine and are not managed by Mason
local pre_installed_servers = {
  sourcekit = true,
}

return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      vim.lsp.config('*', {
        capabilities = vim.tbl_deep_extend(
          'force',
          vim.lsp.protocol.make_client_capabilities(),
          require('cmp_nvim_lsp').default_capabilities()
        ),
      })
      for name, config in pairs(servers) do
        vim.lsp.config(name, config)
        vim.lsp.enable(name)
      end
    end,
    dependencies = {
      {
        'williamboman/mason.nvim',
      },
      {
        'williamboman/mason-lspconfig.nvim',
        version = '*',
        -- It is important for mason and mason-lspconfig's setup to have run before lspconfig's
        priority = 1000,
        config = function()
          local server_names = {}
          for name, _ in pairs(servers) do
            if pre_installed_servers[name] == nil then
              server_names[#server_names + 1] = name
            end
          end
          require('mason-lspconfig').setup({
            ensure_installed = server_names,
            automatic_installation = true,
          })
        end,
      },
      {
        'j-hui/fidget.nvim',
        config = function()
          require('fidget').setup({
            progress = {
              display = {
                progress_icon = { pattern = 'bouncing_bar' },
                done_ttl = 1,
              },
            },
          })
        end,
      },
      {
        'kosayoda/nvim-lightbulb',
        config = function()
          vim.fn.sign_define('LightBulbSign', { text = '▶', texthl = 'DiagnosticSignInfo' })
          require('nvim-lightbulb').setup({
            autocmd = { enabled = true },
            sign = {
              enabled = true,
              text = '▶',
              hl = 'LightBulbSign',
            },
          })
        end,
      },
    },
  },
}
