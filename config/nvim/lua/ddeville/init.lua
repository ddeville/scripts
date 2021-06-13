local M = {}

-- Add support for reporting progress in the ligthline (see `LspStatus` in vimrc)
M.lsp_status_message = function()
  if #vim.lsp.buf_get_clients(0) > 0 then
    local msg = require('lsp-status').status_progress()
    -- Try to prevent the status message from overflowing and thus moving all status items to the left.
    local space = vim.fn.winwidth(0) - 70
    if #msg > space then
      msg = string.sub(msg, 1, space)
    end
    return msg
  else
    return ""
  end
end

return M
