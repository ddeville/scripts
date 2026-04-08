vim.filetype.add({
  filename = {
    Brewfile = 'brewfile',
    Tiltfile = 'tiltfile',
  },
  pattern = {
    ['.*%.Tiltfile'] = 'tiltfile',
  },
})
