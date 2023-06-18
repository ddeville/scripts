return {
  {
    'zbirenbaum/copilot.lua',
    -- Lazily load whenever we use `:Copilot enable`
    cmd = 'Copilot',
    opts = {
      -- Only enable copilot for python and go for now
      filetypes = {
        python = true,
        go = true,
        ['*'] = false,
      },
      -- Disable these since we use copilot-cmp
      suggestion = { enabled = false },
      panel = { enabled = false },
    },
    dependencies = {
      {
        'zbirenbaum/copilot-cmp',
        config = true,
      },
    },
  },
}
