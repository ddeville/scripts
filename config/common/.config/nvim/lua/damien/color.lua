local xdg = require("damien.xdg")

-- setup base16 colorscheme
if vim.fn.filereadable(xdg.state_dir .. "/base16/vimrc_background") == 1 then
    vim.g.base16colorspace = 256
    vim.cmd("source " .. xdg.state_dir .. "/base16/vimrc_background")
end
