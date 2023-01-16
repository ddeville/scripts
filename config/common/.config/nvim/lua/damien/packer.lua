local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
local bootstrapping = false

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
  bootstrapping = true
  vim.fn.execute('!git clone https://github.com/wbthomason/packer.nvim ' .. install_path)
  vim.cmd([[packadd packer.nvim]])
end

local packer = require('packer')
local packer_util = require('packer.util')

packer.startup({
  function(use)
    -- Package manager
    use({
      'wbthomason/packer.nvim',
    })

    -- Appearance
    use({
      'tinted-theming/base16-vim',
      'itchyny/lightline.vim',
      'daviesjamie/vim-base16-lightline',
      'mhinz/vim-startify',
    })

    -- Languages
    use({
      'dag/vim-fish',
      'fatih/vim-go',
      'rust-lang/rust.vim',
      'hashivim/vim-terraform',
      'baskerville/vim-sxhkdrc',
    })

    -- Code formatters
    use({
      'google/vim-codefmt', -- used for Starlark
      requires = {
        'google/vim-maktaba',
        'google/vim-glaive',
      },
    })
    use({
      'ckipp01/stylua-nvim',
    })

    -- Navigation
    use({
      'mhinz/vim-grepper',
      'mattesgroeger/vim-bookmarks',
      'ddeville/telescope-vim-bookmarks.nvim',
    })

    -- LSP
    use({
      'neovim/nvim-lspconfig',
      requires = {
        'kosayoda/nvim-lightbulb',
        'j-hui/fidget.nvim',
      },
    })

    -- Autocompletion
    use({
      'hrsh7th/nvim-cmp',
      requires = {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-nvim-lua',
        'hrsh7th/vim-vsnip',
        'hrsh7th/cmp-vsnip',
      },
    })

    -- Treesitter
    use({
      'nvim-treesitter/nvim-treesitter',
      run = function()
        pcall(require('nvim-treesitter.install').update({ with_sync = true }))
      end,
    })

    -- Telescope
    use({
      'nvim-telescope/telescope.nvim',
      requires = {
        'nvim-lua/popup.nvim',
        'nvim-lua/plenary.nvim',
      },
    })
    use({
      'nvim-telescope/telescope-fzf-native.nvim',
      run = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build',
    })

    -- tpope
    use({
      'tpope/vim-commentary',
      'tpope/vim-eunuch',
      'tpope/vim-fugitive',
      'tpope/vim-git',
      'tpope/vim-repeat',
      'tpope/vim-rhubarb',
      'tpope/vim-sleuth',
      'tpope/vim-surround',
      'tpope/vim-unimpaired',
      'tpope/vim-vinegar',
    })

    if bootstrapping then
      packer.sync()
    end
  end,
  config = {
    display = {
      open_fn = packer_util.float,
    },
    compile_path = vim.fn.stdpath('data') .. '/site/pack/loader/start/packer.nvim/plugin/packer_compiled.lua',
  },
})

-- When we are bootstrapping Packer, it doesn't make sense to execute the rest of the init.lua.
if bootstrapping then
  print('==================================')
  print('    Plugins are being installed')
  print('    Wait until Packer completes,')
  print('       then restart nvim')
  print('==================================')
end
