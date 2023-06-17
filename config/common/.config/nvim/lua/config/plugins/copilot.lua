return {
  {
    'github/copilot.vim',
    -- Lazily load whenever we use `:Copilot enable`
    cmd = 'Copilot',
    config = function()
      -- Only enable copilot for python and go for now
      vim.g.copilot_filetypes = {
        ['*'] = false,
        python = true,
        go = true,
      }
    end,
  },
}
