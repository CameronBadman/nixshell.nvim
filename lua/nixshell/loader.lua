local M = {}

local config = require('nixshell.config')
local api = require('nixshell.api')
local utils = require('nixshell.utils')

-- State
local state = {
  current_dir = nil,
  loaded_extension = nil,
  cleanup_functions = {},
}

-- Check if we're in a nixshell environment
function M.is_nixshell()
  -- Use custom detection if provided
  if config.options.custom_detection then
    return config.options.custom_detection()
  end
  
  -- Check environment variables
  for _, var in ipairs(config.options.detection.env_vars) do
    if vim.env[var] then
      return true
    end
  end
  
  -- Check for files
  local cwd = vim.fn.getcwd()
  for _, file in ipairs(config.options.detection.files) do
    if vim.fn.filereadable(cwd .. "/" .. file) == 1 then
      return true
    end
  end
  
  return false
end

-- Create sandbox environment for extension
local function create_sandbox()
  local env = {}
  
  -- Add allowed globals
  for _, global in ipairs(config.options.sandbox.globals) do
    if global == "os" then
      -- Restrict os functions
      env.os = {}
      for _, fn in ipairs(config.options.sandbox.restricted_os) do
        env.os[fn] = os[fn]
      end
    else
      env[global] = _G[global]
    end
  end
  
  -- Add nixshell API
  env.nixshell = api.get_extension_api()
  
  -- Set metatable for undefined access
  setmetatable(env, {
    __index = function(_, key)
      api.log(string.format("Extension tried to access undefined global: %s", key), vim.log.levels.WARN)
      return nil
    end
  })
  
  return env
end

-- Execute extension code
local function execute_extension(code, source)
  -- Create sandbox
  local env = create_sandbox()
  
  -- Load the code
  local chunk, err = loadstring(code, source)
  if not chunk then
    api.log("Failed to load extension: " .. err, vim.log.levels.ERROR)
    if config.options.notify then
      vim.notify("[nixshell] Failed to load extension: " .. err, vim.log.levels.ERROR)
    end
    return false
  end
  
  -- Set environment
  setfenv(chunk, env)
  
  -- Execute
  local success, result = pcall(chunk)
  if not success then
    api.log("Extension error: " .. result, vim.log.levels.ERROR)
    if config.options.notify then
      vim.notify("[nixshell] Extension error: " .. result, vim.log.levels.ERROR)
    end
    return false
  end
  
  return true
end

-- Load extension from various sources
function M.load_extension()
  local cwd = vim.fn.getcwd()
  
  -- Skip if we're in the same directory and already loaded
  if state.current_dir == cwd and state.loaded_extension then
    return
  end
  
  -- Clean up if directory changed
  if state.current_dir ~= cwd then
    M.cleanup_extension()
    state.current_dir = cwd
  end
  
  -- Pre-load hook
  if config.options.pre_load then
    local ok, err = pcall(config.options.pre_load)
    if not ok then
      api.log("Pre-load hook error: " .. err, vim.log.levels.WARN)
    end
  end
  
  -- Priority 1: Check NVIM_EXTENSION_PATH (file path)
  local extension_path = vim.env[config.options.env_vars.extension_path]
  if extension_path and vim.fn.filereadable(extension_path) == 1 then
    local content = utils.read_file(extension_path)
    if content and execute_extension(content, "env:" .. config.options.env_vars.extension_path) then
      state.loaded_extension = "path"
      api.log("Loaded extension from " .. config.options.env_vars.extension_path)
      if config.options.notify then
        vim.notify("[nixshell] Extension loaded from environment path", vim.log.levels.INFO)
      end
      M._post_load()
      return
    end
  end
  
  -- Priority 2: Check NVIM_EXTENSION_LUA (direct code)
  local extension_lua = vim.env[config.options.env_vars.extension_lua]
  if extension_lua and extension_lua ~= "" then
    if execute_extension(extension_lua, "env:" .. config.options.env_vars.extension_lua) then
      state.loaded_extension = "lua"
      api.log("Loaded extension from " .. config.options.env_vars.extension_lua)
      if config.options.notify then
        vim.notify("[nixshell] Extension loaded from environment variable", vim.log.levels.INFO)
      end
      M._post_load()
      return
    end
  end
  
  -- Priority 3: Check for nvim-extension.lua in current directory
  local local_extension = cwd .. "/nvim-extension.lua"
  if vim.fn.filereadable(local_extension) == 1 then
    local content = utils.read_file(local_extension)
    if content and execute_extension(content, "file:" .. local_extension) then
      state.loaded_extension = "file"
      api.log("Loaded extension from " .. local_extension)
      if config.options.notify then
        vim.notify("[nixshell] Extension loaded from local file", vim.log.levels.INFO)
      end
      M._post_load()
      return
    end
  end
end

-- Post-load hook
function M._post_load()
  if config.options.post_load then
    local ok, err = pcall(config.options.post_load)
    if not ok then
      api.log("Post-load hook error: " .. err, vim.log.levels.WARN)
    end
  end
end

-- Clean up extension
function M.cleanup_extension()
  -- Run cleanup functions
  for _, cleanup_fn in ipairs(state.cleanup_functions) do
    local ok, err = pcall(cleanup_fn)
    if not ok then
      api.log("Cleanup error: " .. err, vim.log.levels.WARN)
    end
  end
  
  -- Reset state
  state.cleanup_functions = {}
  state.loaded_extension = nil
  api.log("Extension cleaned up")
end

-- Register cleanup function (called by extensions)
function M.register_cleanup(fn)
  if type(fn) == "function" then
    table.insert(state.cleanup_functions, fn)
  end
end

-- Get current state
function M.get_state()
  return {
    current_dir = state.current_dir,
    loaded_extension = state.loaded_extension,
    cleanup_count = #state.cleanup_functions,
  }
end

return M
