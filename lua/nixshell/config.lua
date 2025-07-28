local M = {}

-- Default configuration
M.defaults = {
  -- Auto-load extensions when entering directories
  auto_load = true,
  
  -- Delay before loading extension (ms)
  load_delay = 100,
  
  -- Monitor BufEnter for better directory tracking
  monitor_bufenter = true,
  
  -- Show notifications
  notify = true,
  
  -- Log level (vim.log.levels.DEBUG, INFO, WARN, ERROR)
  log_level = vim.log.levels.INFO,
  
  -- Environment variable names
  env_vars = {
    extension_path = "NVIM_EXTENSION_PATH",
    extension_lua = "NVIM_EXTENSION_LUA",
  },
  
  -- Nixshell detection
  detection = {
    -- Check for these environment variables
    env_vars = {
      "IN_NIX_SHELL",
      "DEVSHELL_DIR",
      "NIX_SHELL_PACKAGES",
    },
    -- Check for these files in the directory
    files = {
      "flake.nix",
      "shell.nix",
      "default.nix",
      ".envrc",
    },
  },
  
  -- Extension sandbox environment
  sandbox = {
    -- Allow access to these globals
    globals = {
      "vim",
      "require",
      "pairs",
      "ipairs",
      "next",
      "print",
      "tostring",
      "tonumber",
      "type",
      "table",
      "string",
      "math",
      "os",
      "error",
      "assert",
      "pcall",
      "xpcall",
      "select",
      "unpack",
      "rawget",
      "rawset",
      "getmetatable",
      "setmetatable",
    },
    -- Restrict os functions
    restricted_os = {
      "date",
      "time",
      "clock",
      "difftime",
    },
  },
  
  -- Custom detection function (optional)
  -- Return true if in a nixshell environment
  custom_detection = nil,
  
  -- Pre-load hook (called before loading extension)
  pre_load = nil,
  
  -- Post-load hook (called after loading extension)
  post_load = nil,
}

-- Current configuration
M.options = {}

-- Setup configuration
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, opts)
  
  -- Validate configuration
  M._validate()
end

-- Validate configuration
function M._validate()
  -- Ensure log level is valid
  local valid_levels = {
    vim.log.levels.DEBUG,
    vim.log.levels.INFO,
    vim.log.levels.WARN,
    vim.log.levels.ERROR,
  }
  
  if not vim.tbl_contains(valid_levels, M.options.log_level) then
    M.options.log_level = vim.log.levels.INFO
  end
  
  -- Ensure functions are actually functions
  if M.options.custom_detection and type(M.options.custom_detection) ~= "function" then
    M.options.custom_detection = nil
    vim.notify("[nixshell] Invalid custom_detection function", vim.log.levels.WARN)
  end
  
  if M.options.pre_load and type(M.options.pre_load) ~= "function" then
    M.options.pre_load = nil
    vim.notify("[nixshell] Invalid pre_load function", vim.log.levels.WARN)
  end
  
  if M.options.post_load and type(M.options.post_load) ~= "function" then
    M.options.post_load = nil
    vim.notify("[nixshell] Invalid post_load function", vim.log.levels.WARN)
  end
end

-- Get a specific option
function M.get(key)
  return M.options[key]
end

-- Update configuration
function M.update(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  M._validate()
end

return M
