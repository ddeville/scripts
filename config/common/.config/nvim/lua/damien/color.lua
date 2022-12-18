local state_dir = os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state"

-- setup base16 colorscheme
if vim.fn.filereadable(state_dir .. "/base16/vimrc_background") == 1 then
    vim.g.base16colorspace = 256
    vim.cmd("source " .. state_dir .. "/base16/vimrc_background")
end
