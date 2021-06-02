local compe = require("compe")

vim.o.completeopt = "menuone,noselect"

compe.setup {
  enabled = true;
  autocomplete = true;
  debug = false;
  min_length = 1;
  preselect = "enable";
  throttle_time = 80;
  source_timeout = 200;
  incomplete_delay = 400;
  max_abbr_width = 100;
  max_kind_width = 100;
  max_menu_width = 100;
  documentation = true;
  source = {
    nvim_lsp = true;
    nvim_lua = true;
    buffer = true;
    path = true;
    spell = true;
  };
}

local check_back_space = function()
  local col = vim.fn.col(".") - 1
  if col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
    return true
  else
    return false
  end
end

-- Use tab to navigate completion menu
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
  elseif check_back_space() then
    return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
  else
    return vim.fn["compe#complete"]()
  end
end
_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return vim.api.nvim_replace_termcodes("<C-p>", true, true, true)
  else
    return vim.api.nvim_replace_termcodes("<S-Tab>", true, true, true)
  end
end
vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})

-- To confirm completion, specifically useful for snippets
vim.api.nvim_set_keymap("i", "<C-y>", "compe#confirm('<C-y>')", {expr = true, silent = true, noremap = true})

-- To close the completion menu without making a selection
vim.api.nvim_set_keymap("i", "<C-e>", "compe#close('<C-e>')", {expr = true, silent = true, noremap = true})
