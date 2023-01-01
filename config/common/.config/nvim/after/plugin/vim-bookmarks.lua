vim.g.bookmark_save_per_working_dir = true
vim.g.bookmark_auto_save = true
vim.g.bookmark_display_annotation = true
vim.g.bookmark_show_toggle_warning = false

local bookmarks = require("telescope").extensions.vim_bookmarks

vim.keymap.set("n", "ma", bookmarks.all)
vim.keymap.set("n", "mb", bookmarks.current_file)
