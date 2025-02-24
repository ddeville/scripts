return {
  {
    'mhinz/vim-grepper',
    config = function()
      vim.g.grepper = {
        tools = { 'rg', 'git', 'grep' },
        highlight = 1,
        rg = {
          -- TODO(damien): Remove --threads=3 once running on macos sequoia isn't so slow.. See https://github.com/BurntSushi/ripgrep/issues/2925
          grepprg = 'rg -H --no-heading --vimgrep --threads=3',
        },
      }

      vim.keymap.set('n', '<leader>f', ':Grepper -tool rg<CR>', { noremap = true, silent = true })
      vim.keymap.set('n', 'gs', '<plug>(GrepperOperator)', { remap = true })
      vim.keymap.set('x', 'gs', '<plug>(GrepperOperator)', { remap = true })
    end,
  },
  {
    'ibhagwan/fzf-lua',
    config = function()
      local fzf = require('fzf-lua')
      local actions = require('fzf-lua.actions')
      fzf.setup({
        'ivy',
        winopts = {
          backdrop = false,
          height = 0.35,
          preview = {
            hidden = 'hidden',
          },
        },
        files = {
          no_header = true,
          no_header_i = true,
          multiprocess = true,
          git_icons = false,
          file_icons = false,
          color_icons = false,
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
      vim.keymap.set('n', '<leader>o', fzf.files, { silent = true })
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
      vim.keymap.set('n', '<leader>t', builtin.find_files)
      vim.keymap.set('n', '<leader>g', builtin.git_files)
      vim.keymap.set('n', '<leader>s', builtin.git_status)
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
  {
    'stevearc/oil.nvim',
    config = function()
      local oil = require('oil')

      oil.setup({
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

      vim.keymap.set('n', '-', '<cmd>Oil<CR>', { desc = 'Open parent directory' })
    end,
    -- Alternatively can use 'nvim-tree/nvim-web-devicons'
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
    lazy = false,
  },
}
