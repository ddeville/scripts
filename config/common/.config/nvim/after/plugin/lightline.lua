-- don't show `-- INSERT --` since we have a fancy status line
vim.opt.showmode = false

-- color scheme and items
vim.g.lightline = {
  colorscheme = "wombat";
  active = {
    left = {{"mode", "paste"}, {"gitbranch", "readonly", "filename", "modified"}, {"lsp_status"}};
  };
  component_function = {
    gitbranch = "fugitive#Head";
  };
}
