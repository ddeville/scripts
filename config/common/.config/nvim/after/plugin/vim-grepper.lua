vim.g.grepper = {
  tools = { "rg", "git", "grep" };
  highlight = 1;
  rg = {
    grepprg = "rg -H --no-heading --hidden --vimgrep";
  };
}

vim.keymap.set("n", "<leader>f", ":Grepper -tool rg<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "gs", "<plug>(GrepperOperator)", {remap = true})
vim.keymap.set("x", "gs", "<plug>(GrepperOperator)", {remap = true})
