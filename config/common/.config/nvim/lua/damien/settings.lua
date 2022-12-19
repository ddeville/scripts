-- vim needs a posix shell and fish is not
if vim.opt.shell == "fish$" then
  vim.opt.shell = [[/bin/bash]]
end

-- dark background is better
vim.opt.background = "dark"

-- allow switching between buffers without saving first
vim.opt.hidden = true

-- if no known file type keep the same indent as the current line
vim.opt.autoindent = true

-- use 4 spaces instead of tabs
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- shorten the delay to transition to normal mode after pressing escape
vim.opt.timeoutlen = 1000
vim.opt.ttimeoutlen = 0

-- set mouse support so that we can select text and tabs
vim.opt.mouse = "a"

-- lower how long it takes for cursor hold to kick off (for code actions for example)
vim.opt.updatetime = 300

-- backspace through anything in insert mode
vim.opt.backspace = [[indent,eol,start]]

-- highlight search results and start searching immediately
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- no swap/backup and store undo files under XDG state dir
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true

-- always show at least one line above/below the cursor (and 5 on each side if not wrapping)
vim.opt.scrolloff = 1
vim.opt.sidescrolloff = 5

-- display the cursor position in the status line
vim.opt.ruler = true

-- display the line number on the left
vim.opt.number = true

-- show the diagnostic ui where the number goes
vim.opt.signcolumn = "number"

-- display a column at 80 char
vim.opt.colorcolumn = "80"

-- highlight the current line
vim.opt.cursorline = true

-- always show the status line even when there is only one window
vim.opt.laststatus = 2

-- autoload file changes
vim.opt.autoread = true

-- open new splits on right and bottom
vim.opt.splitbelow = true
vim.opt.splitright = true

-- don't add an extra space when joining lines
vim.g.nojoinspaces = true

-- netrw
vim.gnetrw_localrmdir = "rm -r"
vim.gnetrw_liststyle = 4
vim.gnetrw_winsize = 85
vim.gnetrw_browse_split = 0

-- don't give |ins-completion-menu| messages.
vim.opt.shortmess:append({ c = true })

-- trailing whitespace is bad
vim.api.nvim_set_hl(0, "WhiteSpaceEOL", { ctermbg = 1 })
local trailing_ag = vim.api.nvim_create_augroup("TrailingWhitespace", { clear = true })
vim.api.nvim_create_autocmd("InsertEnter", {
  group = trailing_ag;
  command = [[match WhiteSpaceEOL /\s\+\%#\@<!$/]];
})
vim.api.nvim_create_autocmd("InsertLeave", {
  group = trailing_ag;
  command = [[match WhiteSpaceEOL /\s\+$/]];
})

-- highlight on yan
local highlight_ag = vim.api.nvim_create_augroup("HighlightOnYank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = highlight_ag;
  callback = function()
    vim.highlight.on_yank { timeout = 350 }
  end
})
