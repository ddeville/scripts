vim.filetype.add({
  filename = {
    Brewfile = 'brewfile',
    Tiltfile = 'tiltfile',
    ['go.work'] = 'gowork',
  },
  pattern = {
    ['.*%.Tiltfile'] = 'tiltfile',
    ['.*%.gotmpl'] = 'gotmpl',
    ['.*%.go%.tmpl'] = 'gotmpl',
  },
})
