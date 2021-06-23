M = {}

M.create_augroup = function(name, cmds)
  vim.api.nvim_command("augroup " .. name)
  vim.api.nvim_command("autocmd!")
  for _, comps in ipairs(cmds) do
    local cmd = table.concat(vim.tbl_flatten{"autocmd", comps}, " ")
    vim.api.nvim_command(cmd)
  end
  vim.api.nvim_command("augroup END")
end

return M
