return {
  {
    'mhinz/vim-grepper',
    config = function()
      vim.g.grepper = {
        tools = { 'rg', 'git', 'grep' },
        highlight = 1,
        rg = {
          grepprg = 'rg -H --no-heading --vimgrep',
        },
      }

      vim.keymap.set('n', '<leader>f', ':Grepper -tool rg<CR>', { noremap = true, silent = true })
      vim.keymap.set('n', 'gs', '<plug>(GrepperOperator)', { remap = true })
      vim.keymap.set('x', 'gs', '<plug>(GrepperOperator)', { remap = true })
    end,
  },
  {
    'nvim-telescope/telescope.nvim',
    version = '*',
    config = function()
      local telescope = require('telescope')
      local builtin = require('telescope.builtin')
      local actions = require('telescope.actions')

      vim.keymap.set('n', '<leader>;', builtin.buffers)
      vim.keymap.set('n', ';', builtin.buffers)
      vim.keymap.set('n', '<leader>o', builtin.find_files)
      vim.keymap.set('n', '<leader>s', builtin.git_status)
      vim.keymap.set('n', '<leader>t', builtin.tags)
      vim.keymap.set('n', '//', builtin.current_buffer_fuzzy_find)

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
      'nvim-lua/popup.nvim',
      'nvim-lua/plenary.nvim',
    },
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
    cond = function()
      return vim.fn.executable('cmake') == 1
    end,
  },
  {
    'mattesgroeger/vim-bookmarks',
    config = function()
      vim.g.bookmark_save_per_working_dir = true
      vim.g.bookmark_auto_save = true
      vim.g.bookmark_display_annotation = true
      vim.g.bookmark_show_toggle_warning = false

      local bookmarks = require('telescope').extensions.vim_bookmarks

      local common_settings = {
        layout_strategy = 'vertical',
      }

      local function all()
        bookmarks.all(common_settings)
      end

      local function current_file()
        bookmarks.current_file(common_settings)
      end

      vim.keymap.set('n', 'ma', all)
      vim.keymap.set('n', 'mb', current_file)
    end,
  },
  'ddeville/telescope-vim-bookmarks.nvim',
}
