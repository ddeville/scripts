local ensure_installed = {
  'awk',
  'bash',
  'c',
  'cmake',
  'comment',
  'cpp',
  'css',
  'diff',
  'dockerfile',
  'fish',
  'git_config',
  'git_rebase',
  'gitattributes',
  'gitignore',
  'go',
  'gomod',
  'gosum',
  'gowork',
  'hcl',
  'html',
  'java',
  'javascript',
  'json',
  'jq',
  'kotlin',
  'lua',
  'luadoc',
  'make',
  'markdown',
  'ninja',
  'objc',
  'proto',
  'python',
  'regex',
  'ruby',
  'rust',
  'sql',
  'starlark',
  'sxhkdrc',
  'terraform',
  'toml',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

local install_dir = vim.fn.stdpath('data') .. '/site'

local function setup_treesitter()
  local treesitter = require('nvim-treesitter')
  treesitter.setup({
    install_dir = install_dir,
  })

  treesitter.install(ensure_installed)

  -- Use existing parsers for custom filetypes.
  vim.treesitter.language.register('starlark', { 'tiltfile' })
  vim.treesitter.language.register('ruby', { 'brewfile' })
  vim.treesitter.language.register('terraform', { 'terraform-vars' })
  vim.treesitter.language.register('go', { 'gowork', 'gotmpl' })

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('TreesitterHighlight', { clear = true }),
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
  })
end

local function update_treesitter()
  local treesitter = require('nvim-treesitter')
  treesitter.setup({
    install_dir = install_dir,
  })
  treesitter.install(ensure_installed):wait(300000)
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    config = setup_treesitter,
    build = update_treesitter,
  },
}
