return {
  {
    'williamboman/mason.nvim',
    version = '*',
    -- It is important for mason and mason-lspconfig's setup to have run before lspconfig's
    priority = 1100,
    build = ':MasonUpdate',
    config = function()
      require('mason').setup({
        install_root_dir = vim.fn.stdpath('data') .. '/mason',
        PATH = 'prepend',
        max_concurrent_installers = 8,
        ui = {
          check_outdated_packages_on_open = true,
          border = 'solid',
          width = 0.8,
          height = 0.8,
          icons = {
            package_installed = '✓',
            package_pending = '➜',
            package_uninstalled = '✗',
          },
        },
      })
    end,
  },
}
