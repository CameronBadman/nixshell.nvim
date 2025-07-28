local M = {}

-- Read file contents
function M.read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

-- Write file contents
function M.write_file(path, content)
  local file = io.open(path, "w")
  if not file then
    return false
  end
  
  file:write(content)
  file:close()
  return true
end

-- Check if a command exists
function M.command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Get git root directory
function M.get_git_root()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(git_root)
end

-- Find file in parent directories
function M.find_file_upward(filename, start_dir)
  start_dir = start_dir or vim.fn.getcwd()
  local current = start_dir
  local root = "/"
  
  if vim.fn.has("win32") == 1 then
    root = current:match("^%a:\\")
  end
  
  while current ~= root do
    local file_path = current .. "/" .. filename
    if vim.fn.filereadable(file_path) == 1 then
      return file_path
    end
    current = vim.fn.fnamemodify(current, ":h")
  end
  
  return nil
end

-- Deep merge tables
function M.deep_merge(t1, t2)
  local result = vim.tbl_deep_extend("force", {}, t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = M.deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

-- Create a debounced function
function M.debounce(fn, delay)
  local timer = nil
  return function(...)
    local args = {...}
    if timer then
      vim.fn.timer_stop(timer)
    end
    timer = vim.fn.timer_start(delay, function()
      fn(unpack(args))
    end)
  end
end

-- Parse environment variable as JSON
function M.parse_json_env(var_name)
  local value = vim.env[var_name]
  if not value then
    return nil
  end
  
  local ok, parsed = pcall(vim.json.decode, value)
  if ok then
    return parsed
  else
    return nil
  end
end

-- Check if path is absolute
function M.is_absolute_path(path)
  if vim.fn.has("win32") == 1 then
    return path:match("^%a:[\\/]") or path:match("^[\\/]")
  else
    return path:sub(1, 1) == "/"
  end
end

-- Normalize path
function M.normalize_path(path)
  return vim.fn.resolve(vim.fn.expand(path))
end

-- Get relative path
function M.get_relative_path(path, base)
  path = M.normalize_path(path)
  base = M.normalize_path(base)
  
  if path:sub(1, #base) == base then
    local relative = path:sub(#base + 1)
    if relative:sub(1, 1) == "/" then
      relative = relative:sub(2)
    end
    return relative
  else
    return path
  end
end

-- Create directory if it doesn't exist
function M.ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

-- Get plugin root directory
function M.get_plugin_root()
  local info = debug.getinfo(1, "S")
  local script_path = info.source:sub(2) -- Remove '@' prefix
  return vim.fn.fnamemodify(script_path, ":h:h:h") -- Go up 3 levels
end

return M
