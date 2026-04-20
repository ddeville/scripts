return {
  {
    'mhinz/vim-grepper',
    keys = {
      { '<leader>f', '<cmd>Grepper -tool rg<CR>', mode = 'n', silent = true },
      { 'gs', '<plug>(GrepperOperator)', mode = 'n', remap = true },
      { 'gs', '<plug>(GrepperOperator)', mode = 'x', remap = true },
    },
    config = function()
      vim.g.grepper = {
        tools = { 'rg', 'git', 'grep' },
        highlight = 1,
        rg = {
          grepprg = 'rg -H --no-heading --vimgrep',
        },
      }
    end,
  },
  {
    'ibhagwan/fzf-lua',
    keys = {
      {
        '<leader>o',
        function()
          require('fzf-lua').files()
        end,
        mode = 'n',
        silent = true,
      },
    },
    config = function()
      local fzf = require('fzf-lua')
      local actions = require('fzf-lua.actions')
      fzf.setup({
        'ivy',
        winopts = {
          backdrop = false,
          height = 1,
          preview = {
            hidden = 'hidden',
          },
        },
        files = {
          no_header = true,
          no_header_i = true,
          multiprocess = true,
          git_icons = false,
          file_icons = 'mini',
          color_icons = true,
          cwd_prompt = false,
          actions = {
            ['ctrl-g'] = { actions.toggle_ignore },
          },
          fd_opts = [[--type file --color=never --hidden --follow --strip-cwd-prefix --exclude .git]],
        },
        fzf_opts = {
          ['--ansi'] = true,
          ['--layout'] = 'default',
          ['--border'] = 'none',
        },
        fzf_colors = {
          -- Just use the telescope theme that will match other pickers...
          ['fg'] = { 'fg', 'TelescopeNormal' },
          ['bg'] = { 'bg', 'TelescopeNormal' },
          ['hl'] = { 'fg', 'TelescopeMatching' },
          ['fg+'] = { 'fg', 'TelescopeSelection' },
          ['bg+'] = { 'bg', 'TelescopeSelection' },
          ['hl+'] = { 'fg', 'TelescopeMatching' },
          ['info'] = { 'fg', 'TelescopeMultiSelection' },
          ['border'] = { 'fg', 'TelescopeBorder' },
          ['gutter'] = '-1',
          ['query'] = { 'fg', 'TelescopePromptNormal' },
          ['prompt'] = { 'fg', 'TelescopePromptPrefix' },
          ['pointer'] = { 'fg', 'TelescopeSelectionCaret' },
          ['marker'] = { 'fg', 'TelescopeSelectionCaret' },
          ['header'] = { 'fg', 'TelescopeTitle' },
        },
      })
    end,
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  },

  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    keys = {
      {
        '<leader>;',
        function()
          require('telescope.builtin').buffers()
        end,
        mode = 'n',
      },
      {
        ';',
        function()
          require('telescope.builtin').buffers()
        end,
        mode = 'n',
      },
      {
        '<leader>t',
        function()
          require('telescope.builtin').find_files()
        end,
        mode = 'n',
      },
      {
        '<leader>g',
        function()
          require('telescope.builtin').git_files()
        end,
        mode = 'n',
      },
      {
        '<leader>s',
        function()
          require('telescope.builtin').git_status()
        end,
        mode = 'n',
      },
      {
        '//',
        function()
          require('telescope.builtin').current_buffer_fuzzy_find()
        end,
        mode = 'n',
      },
    },
    config = function()
      local telescope = require('telescope')
      local actions = require('telescope.actions')

      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ['<esc>'] = actions.close, -- Close when hitting escape in insert mode, rather than going to normal mode
              ['<C-q>'] = actions.smart_send_to_qflist + actions.open_qflist,
            },
            n = {
              ['<C-q>'] = actions.smart_send_to_qflist + actions.open_qflist,
            },
          },
        },
        pickers = {
          buffers = {
            theme = 'ivy',
            previewer = false,
            results_title = false,
            preview_title = false,
            sorting_strategy = 'descending',
            sort_lastused = true,
            sort_mru = true,
            layout_config = {
              height = 0.35,
              prompt_position = 'bottom',
              preview_width = 0.45,
            },
            mappings = {
              i = {
                ['<C-d>'] = actions.delete_buffer,
              },
              n = {
                ['<C-d>'] = actions.delete_buffer,
              },
            },
          },
          find_files = {
            find_command = {
              'fd',
              '--type',
              'file',
              '--color=never',
              '--hidden',
              '--strip-cwd-prefix',
              '--exclude',
              '.git',
            },
            theme = 'ivy',
            results_title = false,
            preview_title = false,
            sorting_strategy = 'descending',
            layout_config = {
              height = 0.35,
              prompt_position = 'bottom',
              preview_width = 0.45,
            },
          },
          git_files = {
            theme = 'ivy',
            results_title = false,
            preview_title = false,
            sorting_strategy = 'descending',
            layout_config = {
              height = 0.35,
              prompt_position = 'bottom',
              preview_width = 0.45,
            },
          },
          current_buffer_fuzzy_find = {
            sorting_strategy = 'ascending',
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'smart_case',
          },
        },
      })

      telescope.load_extension('fzf')
      telescope.load_extension('vim_bookmarks')
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
        cond = function()
          return vim.fn.executable('cmake') == 1
        end,
      },
      'ddeville/telescope-vim-bookmarks.nvim',
    },
  },
  {
    'mattesgroeger/vim-bookmarks',
    config = function()
      vim.g.bookmark_save_per_working_dir = true
      vim.g.bookmark_auto_save = true
      vim.g.bookmark_display_annotation = true
      vim.g.bookmark_show_toggle_warning = false

      vim.keymap.set('n', 'ma', function()
        require('telescope').extensions.vim_bookmarks.all({
          layout_strategy = 'vertical',
        })
      end)

      vim.keymap.set('n', 'mb', function()
        require('telescope').extensions.vim_bookmarks.current_file({
          layout_strategy = 'vertical',
        })
      end)
    end,
  },
  {
    'stevearc/oil.nvim',
    keys = {
      { '-', '<cmd>Oil<CR>', desc = 'Open parent directory', mode = 'n' },
    },
    config = function()
      local oil = require('oil')

      oil.setup({
        skip_confirm_for_simple_edits = true,
        columns = {
          'icon',
        },
        view_options = {
          show_hidden = true,
          -- By default oil.nvim dims hidden entries which is annoying to look at (on top of hiding them by default).
          -- While we already use `show_hidden = true` to show them let's switch to no consider any file as hidden
          -- so that it always shows them using the right highlight.
          is_hidden_file = function(name, bufnr)
            return false
          end,
          natural_order = 'fast',
          case_insensitive = false,
          sort = {
            { 'type', 'asc' },
            { 'name', 'asc' },
          },
        },
      })
    end,
    -- Alternatively can use 'nvim-tree/nvim-web-devicons'
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  },
}
