local telescope = require("telescope")
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")

vim.keymap.set("n", "<leader>;", builtin.buffers)
vim.keymap.set("n", ";", builtin.buffers)
vim.keymap.set("n", "<leader>o", builtin.find_files)
vim.keymap.set("n", "<leader>s", builtin.git_status)
vim.keymap.set("n", "<leader>t", builtin.tags)
vim.keymap.set("n", "//", builtin.current_buffer_fuzzy_find)

telescope.setup {
  defaults = {
    mappings = {
      i = {
        ["<esc>"] = actions.close,  -- Close when hitting escape in insert mode, rather than going to normal mode
        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist;
      };
      n = {
        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist;
      }
    };
  };
  pickers = {
    buffers = {
      theme = "ivy";
      results_title = false;
      preview_title = false;
      sorting_strategy = "descending";
      sort_lastused = true;
      sort_mru = true;
      layout_config = {
        height = 0.35;
        prompt_position = "bottom";
        preview_width = 0.45;
      };
      mappings = {
        i = {
          ["<C-d>"] = actions.delete_buffer;
        };
        n = {
          ["<C-d>"] = actions.delete_buffer;
        };
      };
    };
    find_files = {
      find_command = { "fd", "--type", "file", "--color=never", "--hidden", "--strip-cwd-prefix", "--exclude", ".git" };
      theme = "ivy";
      results_title = false;
      preview_title = false;
      sorting_strategy = "descending";
      layout_config = {
        height = 0.35;
        prompt_position = "bottom";
        preview_width = 0.45;
      };
    };
  };
  extensions = {
    fzf = {
      fuzzy = true;
      override_generic_sorter = true;
      override_file_sorter = true;
      case_mode = "smart_case";
    };
  };
}

telescope.load_extension("fzf")
telescope.load_extension("vim_bookmarks")
