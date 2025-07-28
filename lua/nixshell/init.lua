local M = {}

-- Import modules
local config = require('nixshell.config')
local loader = require('nixshell.loader')
local api = require('nixshell.api')

-- Plugin state
M._state = {
  initialized = false,
  current_dir = nil,
  loaded_extension = nil,
}

-- Setup function
function M.setup(opts)
  if M._state.initialized then
    return
  end
  
  -- Initialize configuration
  config.setup(opts)
  
  -- Initialize the API
  api.init()
  
  -- Setup autocommands
  local augroup = vim.api.nvim_create_augroup("NixshellNvim", { clear = true })
  
  -- Load on startup if in nixshell
  if loader.is_nixshell() then
    vim.defer_fn(function()
      loader.load_extension()
    end, config.options.load_delay)
  end
  
  -- Reload on directory change
  vim.api.nvim_create_autocmd("DirChanged", {
    group = augroup,
    callback = function()
      if config.options.auto_load then
        if loader.is_nixshell() then
          loader.load_extension()
        else
          loader.cleanup_extension()
        end
      end
    end
  })
  
  -- Monitor BufEnter for better directory tracking
  if config.options.monitor_bufenter then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      callback = function()
        local current = vim.fn.getcwd()
        if current ~= M._state.current_dir then
          M._state.current_dir = current
          if config.options.auto_load and loader.is_nixshell() then
            loader.load_extension()
          end
        end
      end
    })
  end
  
  -- Setup user commands
  M._setup_commands()
  
  M._state.initialized = true
end

-- Setup user commands
function M._setup_commands()
  -- Status command
  vim.api.nvim_create_user_command("NixshellStatus", function()
    api.show_status()
  end, { desc = "Show nixshell.nvim status" })
  
  -- Reload command
  vim.api.nvim_create_user_command("NixshellReload", function()
    loader.cleanup_extension()
    loader.load_extension()
    vim.notify("[nixshell] Extension reloaded", vim.log.levels.INFO)
  end, { desc = "Reload nixshell extension" })
  
  -- Logs command
  vim.api.nvim_create_user_command("NixshellLogs", function()
    api.show_logs()
  end, { desc = "Show nixshell logs" })
  
  -- Clear logs command
  vim.api.nvim_create_user_command("NixshellClearLogs", function()
    api.clear_logs()
    vim.notify("[nixshell] Logs cleared", vim.log.levels.INFO)
  end, { desc = "Clear nixshell logs" })
  
  -- Load command (manual loading)
  vim.api.nvim_create_user_command("NixshellLoad", function()
    loader.load_extension()
  end, { desc = "Manually load nixshell extension" })
  
  -- Unload command
  vim.api.nvim_create_user_command("NixshellUnload", function()
    loader.cleanup_extension()
    vim.notify("[nixshell] Extension unloaded", vim.log.levels.INFO)
  end, { desc = "Unload nixshell extension" })
end

-- Public API
M.get_status = api.get_status
M.reload = function()
  loader.cleanup_extension()
  loader.load_extension()
end

return M
