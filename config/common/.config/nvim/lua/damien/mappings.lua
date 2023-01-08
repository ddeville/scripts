-- set leader to space instead of the default backslash
vim.g.mapleader = ' '
vim.keymap.set('n', '<space>', '<nop>')

-- disable arrow keys
vim.keymap.set('', '<up>', '<nop>')
vim.keymap.set('', '<up>', '<nop>')
vim.keymap.set('', '<down>', '<nop>')
vim.keymap.set('', '<left>', '<nop>')
vim.keymap.set('', '<right>', '<nop>')
vim.keymap.set('i', '<up>', '<nop>')
vim.keymap.set('i', '<up>', '<nop>')
vim.keymap.set('i', '<down>', '<nop>')
vim.keymap.set('i', '<left>', '<nop>')
vim.keymap.set('i', '<right>', '<nop>')

-- search current selection in visual mode with */#
vim.cmd([[
function! DamienVSetSearch()
  let temp = @@
  norm! gvy
  let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
  let @@ = temp
endfunction
]])
vim.keymap.set('v', '*', ':<C-u>call DamienVSetSearch()<CR>//<CR><c-o>')
vim.keymap.set('v', '#', ':<C-u>call DamienVSetSearch()<CR>??<CR><c-o>')

-- move lines up and down when in visual mode
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- map screen redraw to also turn off search highlighting
vim.keymap.set('n', '<C-l>', ':nohl<CR><C-l>')

-- make Y behave like D and C
vim.keymap.set('n', 'Y', 'y$')

-- don't clobber the yank register when deleting with x
vim.keymap.set({ 'n', 'x' }, 'x', '"_x')

-- integration with system clipboard
vim.keymap.set('n', '<leader>y', '"+y')
vim.keymap.set('v', '<leader>y', '"+y')
vim.keymap.set('n', '<leader>Y', '"+Y')
vim.keymap.set('n', '<leader>p', '"+p')
vim.keymap.set('v', '<leader>p', '"+p')
vim.keymap.set('n', '<leader>P', '"+P')
