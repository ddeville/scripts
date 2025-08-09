-- vim needs a posix shell and fish is not
if vim.o.shell:sub(-5) == '/fish' then
  vim.o.shell = [[/bin/bash]]
end

-- dark background is better
vim.opt.background = 'dark'

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
vim.opt.mouse = 'a'

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
vim.opt.signcolumn = 'number'

-- display a column at 120 char
vim.opt.colorcolumn = '120'

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
vim.gnetrw_localrmdir = 'rm -r'
vim.gnetrw_liststyle = 4
vim.gnetrw_winsize = 85
vim.gnetrw_browse_split = 0

-- don't give |ins-completion-menu| messages.
vim.opt.shortmess:append({ c = true })

-- trailing whitespace is bad
vim.api.nvim_set_hl(0, 'WhiteSpaceEOL', { ctermbg = 1 })
local trailing_ag = vim.api.nvim_create_augroup('TrailingWhitespace', { clear = true })
vim.api.nvim_create_autocmd('InsertEnter', {
  group = trailing_ag,
  command = [[match WhiteSpaceEOL /\s\+\%#\@<!$/]],
})
vim.api.nvim_create_autocmd('InsertLeave', {
  group = trailing_ag,
  command = [[match WhiteSpaceEOL /\s\+$/]],
})

-- highlight on yank
local highlight_ag = vim.api.nvim_create_augroup('HighlightOnYank', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  group = highlight_ag,
  callback = function()
    vim.highlight.on_yank({ timeout = 350 })
  end,
})

-- disable lsp logs
vim.lsp.set_log_level('off')

-- disable lsp semantic tokens since we use treesitter for syntax highlighting anyway...
-- (see https://www.reddit.com/r/neovim/comments/109vgtl/how_to_disable_highlight_from_lsp)
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('LspDisableSemanticTokensProvider', {}),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})

-- setup diagnostics
vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 4,
    -- Show WARN and above in virtual text
    severity = { min = vim.diagnostic.severity.WARN },
  },
  signs = {
    priority = 40, -- Keep signs above most others (e.g., VCS)
    text = {
      [vim.diagnostic.severity.ERROR] = 'E',
      [vim.diagnostic.severity.WARN] = 'W',
      [vim.diagnostic.severity.INFO] = 'I',
      [vim.diagnostic.severity.HINT] = 'H',
    },
  },
  float = { scope = 'line' },
})

-- diagnostic highlights
vim.api.nvim_set_hl(0, 'DiagnosticError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { fg = 'Red', ctermfg = 'Red', underline = true })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingError', { fg = 'Red', ctermfg = 'Red' })
vim.api.nvim_set_hl(0, 'DiagnosticSignError', { fg = 'Red', ctermfg = 'Red' })

vim.api.nvim_set_hl(0, 'DiagnosticWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { fg = 'Yellow', ctermfg = 'Yellow', underline = true })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingWarn', { fg = 'Yellow', ctermfg = 'Yellow' })
vim.api.nvim_set_hl(0, 'DiagnosticSignWarn', { fg = 'Yellow', ctermfg = 'Yellow' })

vim.api.nvim_set_hl(0, 'DiagnosticInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { fg = 'White', ctermfg = 'White', underline = true })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingInfo', { fg = 'White', ctermfg = 'White' })
vim.api.nvim_set_hl(0, 'DiagnosticSignInfo', { fg = 'White', ctermfg = 'White' })

vim.api.nvim_set_hl(0, 'DiagnosticHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { fg = 'Gray', ctermfg = 'Gray', underline = true })
vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticFloatingHint', { fg = 'Gray', ctermfg = 'Gray' })
vim.api.nvim_set_hl(0, 'DiagnosticSignHint', { fg = 'Gray', ctermfg = 'Gray' })
