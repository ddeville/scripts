local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local spec = {
  { 'folke/lazy.nvim', tag = 'stable' },
  { import = 'config.plugins' },
}
local opts = {
  change_detection = {
    enabled = true,
    notify = false,
  },
  checker = {
    enabled = false,
  },
  ui = {
    size = { width = 0.8, height = 0.8 },
    border = 'solid',
  },
}
require('lazy').setup(spec, opts)
