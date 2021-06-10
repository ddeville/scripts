local treesitter = require("nvim-treesitter.configs")

treesitter.setup {
  ensure_installed = {
    "bash",
    "c",
    "comment",
    "cpp",
    "css",
    "dockerfile",
    "fish",
    "go",
    "html",
    "java",
    "javascript",
    "json",
    "kotlin",
    "lua",
    "python",
    "rust",
    "toml",
    "typescript",
    "yaml",
  };
  highlight = {
    enable = true;
  };
}
