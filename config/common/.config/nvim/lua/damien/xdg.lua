local M = {}

M.config_dir = os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config"
M.data_dir = os.getenv("XDG_DATA_HOME") or os.getenv("HOME") .. "/.local/share"
M.state_dir = os.getenv("XDG_STATE_HOME") or os.getenv("HOME") .. "/.local/state"

return M
