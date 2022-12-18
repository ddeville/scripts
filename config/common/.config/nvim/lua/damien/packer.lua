local install_path = vim.fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
local bootstrapping = false

if vim.fn.empty(vim.fn.glob(install_path)) > 0 then
    bootstrapping = true
    vim.fn.execute("!git clone https://github.com/wbthomason/packer.nvim " .. install_path)
    vim.cmd [[packadd packer.nvim]]
end

require('packer').startup(function(use)
    -- Package manager
    use "wbthomason/packer.nvim"

    -- Color scheme
    use "chriskempson/base16-vim"

    -- Languages
    use "dag/vim-fish"
    use "fatih/vim-go"
    use "rust-lang/rust.vim"
    use "hashivim/vim-terraform"
    use "baskerville/vim-sxhkdrc"

    -- Google formatter (used for Starlark)
    use {
        "google/vim-codefmt",
        requires = {
            "google/vim-maktaba",
        },
    }

    -- fzf
    use {
        "junegunn/fzf.vim",
        requires = {
            { "junegunn/fzf" }
        }
    }

    use "itchyny/lightline.vim"
    use "mhinz/vim-grepper"
    use "mhinz/vim-startify"
    use "tpope/vim-commentary"
    use "tpope/vim-eunuch"
    use "tpope/vim-fugitive"
    use "tpope/vim-git"
    use "tpope/vim-repeat"
    use "tpope/vim-rhubarb"
    use "tpope/vim-sleuth"
    use "tpope/vim-surround"
    use "tpope/vim-unimpaired"
    use "tpope/vim-vinegar"

    -- TODO(damien): Remove
    use "machakann/vim-highlightedyank"

    -- Autocompletion
    use {
        "hrsh7th/nvim-cmp",
        requires = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-nvim-lua",
            "hrsh7th/vim-vsnip",
            "hrsh7th/cmp-vsnip",
        },
    }

    -- LSP
    use {
        "neovim/nvim-lspconfig",
        requires = {
            "nvim-lua/lsp-status.nvim",
            "kosayoda/nvim-lightbulb",
            -- TODO(damien): Enable
            -- "j-hui/fidget.nvim",
        },
    }

    -- Treesitter
    use {
        "nvim-treesitter/nvim-treesitter",
        run = function()
            pcall(require('nvim-treesitter.install').update { with_sync = true })
        end,
    }

    -- Telescope
    use {
        "nvim-telescope/telescope.nvim",
        requires = {
            "nvim-lua/popup.nvim",
            "nvim-lua/plenary.nvim",
        },
    }


  -- Fuzzy Finder Algorithm which requires local dependencies to be built. Only load if `make` is available
  -- use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make', cond = vim.fn.executable 'make' == 1 }

    if bootstrapping then
        require('packer').sync()
    end
end)

-- When we are bootstrapping Packer, it doesn't make sense to execute the rest of the init.lua.
if bootstrapping then
    print "=================================="
    print "    Plugins are being installed"
    print "    Wait until Packer completes,"
    print "       then restart nvim"
    print "=================================="
end
