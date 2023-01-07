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
