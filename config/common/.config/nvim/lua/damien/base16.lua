local state_dir = os.getenv('XDG_STATE_HOME') or os.getenv('HOME') .. '/.local/state'

-- setup base16 colorscheme
local set_theme_path = state_dir .. '/base16/set_theme.lua'
if vim.fn.filereadable(vim.fn.expand(set_theme_path)) == 1 then
  vim.g.base16colorspace = 256
  vim.cmd('source ' .. set_theme_path)
end
