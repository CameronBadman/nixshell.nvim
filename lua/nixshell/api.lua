local M = {}

local config = require('nixshell.config')

-- State
local state = {
  logs = {},
  max_logs = 100,
}

-- Initialize API
function M.init()
  state.logs = {}
end

-- Logging function
function M.log(msg, level)
  level = level or vim.log.levels.INFO
  
  -- Only log if level is high enough
  if level < config.options.log_level then
    return
  end
  
  -- Add timestamp
  local entry = {
    time = os.date("%H:%M:%S"),
    level = level,
    message = msg,
  }
  
  table.insert(state.logs, entry)
  
  -- Trim logs if too many
  if #state.logs > state.max_logs then
    table.remove(state.logs, 1)
  end
end

-- Get extension API (provided to extensions)
function M.get_extension_api()
  local loader = require('nixshell.loader')
  
  return {
    -- Logging
    log = function(msg)
      M.log(msg, vim.log.levels.INFO)
    end,
    
    -- Debug logging
    debug = function(msg)
      M.log(msg, vim.log.levels.DEBUG)
    end,
    
    -- Warning
    warn = function(msg)
      M.log(msg, vim.log.levels.WARN)
    end,
    
    -- Error
    error = function(msg)
      M.log(msg, vim.log.levels.ERROR)
    end,
    
    -- Register cleanup function
    register_cleanup = function(fn)
      loader.register_cleanup(fn)
    end,
    
    -- Get current working directory
    cwd = function()
      return vim.fn.getcwd()
    end,
    
    -- Get nixshell environment info
    env = function()
      return {
        IN_NIX_SHELL = vim.env.IN_NIX_SHELL,
        DEVSHELL_DIR = vim.env.DEVSHELL_DIR,
        NIX_SHELL_PACKAGES = vim.env.NIX_SHELL_PACKAGES,
        NVIM_EXTENSION_PATH = vim.env[config.options.env_vars.extension_path],
        NVIM_EXTENSION_LUA = vim.env[config.options.env_vars.extension_lua] and true or false,
      }
    end,
    
    -- Utility to create buffer-local settings
    buf_settings = function(settings)
      for key, value in pairs(settings) do
        vim.api.nvim_buf_set_option(0, key, value)
      end
    end,
    
    -- Utility to create window-local settings
    win_settings = function(settings)
      for key, value in pairs(settings) do
        vim.api.nvim_win_set_option(0, key, value)
      end
    end,
    
    -- Check if file exists
    file_exists = function(path)
      return vim.fn.filereadable(path) == 1
    end,
    
    -- Read file contents
    read_file = function(path)
      local utils = require('nixshell.utils')
      return utils.read_file(path)
    end,
  }
end

-- Show status
function M.show_status()
  local loader = require('nixshell.loader')
  local state = loader.get_state()
  
  local status_lines = {
    "Nixshell Status",
    "===============",
    "",
    "Current directory: " .. (state.current_dir or "none"),
    "Loaded extension: " .. (state.loaded_extension or "none"),
    "Cleanup functions: " .. state.cleanup_count,
    "",
    "Environment Variables:",
    "  " .. config.options.env_vars.extension_path .. ": " .. 
      (vim.env[config.options.env_vars.extension_path] or "not set"),
    "  " .. config.options.env_vars.extension_lua .. ": " .. 
      (vim.env[config.options.env_vars.extension_lua] and "set" or "not set"),
    "",
    "Nixshell Detection:",
    "  IN_NIX_SHELL: " .. (vim.env.IN_NIX_SHELL or "not set"),
    "  DEVSHELL_DIR: " .. (vim.env.DEVSHELL_DIR or "not set"),
    "",
    "Configuration:",
    "  Auto-load: " .. tostring(config.options.auto_load),
    "  Load delay: " .. config.options.load_delay .. "ms",
    "  Log level: " .. M._level_to_string(config.options.log_level),
  }
  
  -- Use floating window for better display
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, status_lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  local width = 60
  local height = #status_lines
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Nixshell Status ',
    title_pos = 'center',
  }
  
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':close<CR>', { noremap = true, silent = true })
end

-- Show logs
function M.show_logs()
  if #state.logs == 0 then
    vim.notify("[nixshell] No logs available", vim.log.levels.INFO)
    return
  end
  
  local log_lines = { "Nixshell Logs", "=============", "" }
  
  for _, entry in ipairs(state.logs) do
    local level_str = M._level_to_string(entry.level)
    local line = string.format("%s [%s] %s", entry.time, level_str, entry.message)
    table.insert(log_lines, line)
  end
  
  -- Use floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, log_lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#log_lines, vim.o.lines - 10)
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Nixshell Logs ',
    title_pos = 'center',
  }
  
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Keymaps
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', { noremap = true, silent = true })
  
  -- Syntax highlighting for log levels
  vim.api.nvim_buf_call(buf, function()
    vim.cmd('syntax match NixshellLogDebug "\\[DEBUG\\]"')
    vim.cmd('syntax match NixshellLogInfo "\\[INFO\\]"')
    vim.cmd('syntax match NixshellLogWarn "\\[WARN\\]"')
    vim.cmd('syntax match NixshellLogError "\\[ERROR\\]"')
    vim.cmd('highlight NixshellLogDebug ctermfg=Gray guifg=Gray')
    vim.cmd('highlight NixshellLogInfo ctermfg=Green guifg=Green')
    vim.cmd('highlight NixshellLogWarn ctermfg=Yellow guifg=Yellow')
    vim.cmd('highlight NixshellLogError ctermfg=Red guifg=Red')
  end)
end

-- Clear logs
function M.clear_logs()
  state.logs = {}
end

-- Get status information
function M.get_status()
  local loader = require('nixshell.loader')
  return loader.get_state()
end

-- Convert log level to string
function M._level_to_string(level)
  if level == vim.log.levels.DEBUG then
    return "DEBUG"
  elseif level == vim.log.levels.INFO then
    return "INFO"
  elseif level == vim.log.levels.WARN then
    return "WARN"
  elseif level == vim.log.levels.ERROR then
    return "ERROR"
  else
    return "UNKNOWN"
  end
end

return M
