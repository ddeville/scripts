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

-- support deleting without clobbering the default register
vim.keymap.set('n', '<leader>d', '"_d')
vim.keymap.set('v', '<leader>d', '"_d')
vim.keymap.set('n', '<leader>D', '"_D')
vim.keymap.set('n', '<leader>c', '"_c')
vim.keymap.set('v', '<leader>c', '"_c')
vim.keymap.set('n', '<leader>C', '"_C')

-- integration with system clipboard
vim.keymap.set('n', '<leader>y', '"+y')
vim.keymap.set('v', '<leader>y', '"+y')
vim.keymap.set('n', '<leader>Y', '"+Y')
vim.keymap.set('n', '<leader>p', '"+p')
vim.keymap.set('v', '<leader>p', '"+p')
vim.keymap.set('n', '<leader>P', '"+P')

-- diagnostic
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
vim.keymap.set('n', ']g', function()
  vim.diagnostic.jump({ count = 1 })
end)
vim.keymap.set('n', '[g', function()
  vim.diagnostic.jump({ count = -1 })
end)

-- lsp
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('LspKeymapConfig', {}),
  callback = function(args)
    -- enable completion triggered by <c-x><c-o>
    vim.bo[args.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- buffer local mappings.
    local opts = { buffer = args.buf }
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', 'gy', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>a', vim.lsp.buf.code_action, opts)
  end,
})

-- quickfix
vim.keymap.set('n', '<C-j>', '<cmd>cnext<CR>')
vim.keymap.set('n', '<C-k>', '<cmd>cprevious<CR>')
