---@class RegexplainerDepsConfig
---@field auto_install? boolean # Whether to auto-install dependencies (default: true)
---@field python_cmd? string # Python command to use (default: auto-detect)
---@field venv_path? string # Custom venv path (default: plugin_dir/.venv)
---@field check_interval? number # How often to check deps in seconds (default: 3600)

local utils = require 'regexplainer.utils'

local M = {}

-- Default configuration
local default_config = {
  auto_install = true,
  python_cmd = nil, -- Will be auto-detected
  venv_path = nil, -- Will be auto-generated
  check_interval = 3600, -- 1 hour
}

-- Cache for dependency check results
local _cache = {
  last_check = 0,
  python_cmd = nil,
  venv_python = nil,
  deps_available = false,
  venv_exists = false,
}

--- Get plugin directory path
---@return string
local function get_plugin_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(source, ':h:h:h')
end

--- Get virtual environment path
---@param config RegexplainerDepsConfig
---@return string
local function get_venv_path(config)
  if config.venv_path then
    return vim.fn.expand(config.venv_path)
  end
  return vim.fn.join({ get_plugin_dir(), '.venv' }, '/')
end

--- Get virtual environment python executable path
---@param config RegexplainerDepsConfig
---@return string
local function get_venv_python_path(config)
  local venv_path = get_venv_path(config)
  local is_windows = vim.fn.has 'win32' == 1 or vim.fn.has 'win64' == 1
  if is_windows then
    return vim.fn.join({ venv_path, 'Scripts', 'python.exe' }, '/')
  else
    return vim.fn.join({ venv_path, 'bin', 'python' }, '/')
  end
end

--- Check if a command exists and is executable
---@param cmd string
---@return boolean
local function is_executable(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Run a shell command and return result
---@param cmd string
---@param timeout? number # Timeout in milliseconds
---@return boolean success, string stdout, string stderr
local function run_command(cmd, timeout)
  timeout = timeout or 30000 -- 30 second default timeout

  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  return exit_code == 0, result, exit_code ~= 0 and result or ''
end

--- Find suitable Python executable
---@return string|nil python_cmd, string|nil version
local function find_python()
  local candidates = { 'python3', 'python' }

  for _, cmd in ipairs(candidates) do
    if is_executable(cmd) then
      local success, output = run_command(cmd .. ' --version 2>&1')
      if success then
        local version = output:match 'Python (%d+%.%d+%.%d+)'
        if version then
          -- Check if version is >= 3.9
          local major, minor = version:match '(%d+)%.(%d+)'
          if tonumber(major) >= 3 and tonumber(minor) >= 9 then
            return cmd, version
          end
        end
      end
    end
  end

  return nil, nil
end

--- Check if required Python packages are available in given environment
---@param python_cmd string
---@return boolean success, table missing_packages
local function check_python_packages(python_cmd)
  local required_packages = {
    'railroad',
    'PIL', -- Pillow
    'cairosvg',
  }

  local missing = {}

  for _, package in ipairs(required_packages) do
    local cmd = string.format('%s -c "import %s" 2>/dev/null', vim.fn.shellescape(python_cmd), package)
    local success = run_command(cmd)
    if not success then
      table.insert(missing, package)
    end
  end

  return #missing == 0, missing
end

--- Check if virtual environment exists
---@param config RegexplainerDepsConfig
---@return boolean
local function venv_exists(config)
  local venv_python = get_venv_python_path(config)
  return vim.fn.filereadable(venv_python) == 1
end

--- Create virtual environment
---@param config RegexplainerDepsConfig
---@param python_cmd string
---@return boolean success, string error_msg
local function create_venv(config, python_cmd)
  local venv_path = get_venv_path(config)

  -- Create parent directory if it doesn't exist
  local parent_dir = vim.fn.fnamemodify(venv_path, ':h')
  if vim.fn.isdirectory(parent_dir) == 0 then
    local success = vim.fn.mkdir(parent_dir, 'p')
    if success == 0 then
      return false, 'Failed to create parent directory: ' .. parent_dir
    end
  end

  -- Create virtual environment
  local cmd = string.format('%s -m venv %s', vim.fn.shellescape(python_cmd), vim.fn.shellescape(venv_path))

  local success, stdout, stderr = run_command(cmd, 60000) -- 1 minute timeout
  if not success then
    return false, 'Failed to create virtual environment: ' .. stderr
  end

  return true, ''
end

--- Install packages in virtual environment
---@param config RegexplainerDepsConfig
---@param packages string[]
---@return boolean success, string error_msg
local function install_packages(config, packages)
  local venv_python = get_venv_python_path(config)

  if vim.fn.filereadable(venv_python) ~= 1 then
    return false, 'Virtual environment not found: ' .. venv_python
  end

  -- Map package names for pip installation
  local pip_packages = {}
  for _, pkg in ipairs(packages) do
    if pkg == 'railroad' then
      table.insert(pip_packages, 'railroad-diagrams')
    elseif pkg == 'PIL' then
      table.insert(pip_packages, 'Pillow')
    else
      table.insert(pip_packages, pkg)
    end
  end

  local packages_str = table.concat(vim.tbl_map(vim.fn.shellescape, pip_packages), ' ')
  local cmd =
    string.format('%s -m pip install --no-warn-script-location %s', vim.fn.shellescape(venv_python), packages_str)

  local success, stdout, stderr = run_command(cmd, 120000) -- 2 minute timeout
  if not success then
    return false, 'Failed to install packages: ' .. stderr
  end

  return true, ''
end

--- Setup virtual environment with required packages
---@param config RegexplainerDepsConfig
---@return boolean success, string error_msg
local function setup_venv(config)
  -- Find Python
  local python_cmd, version = find_python()
  if not python_cmd then
    return false, 'No suitable Python installation found (requires Python 3.9+)'
  end

  -- Create venv if it doesn't exist
  if not venv_exists(config) then
    local success, err = create_venv(config, python_cmd)
    if not success then
      return false, err
    end
  end

  -- Check what packages are missing
  local venv_python = get_venv_python_path(config)
  local packages_ok, missing_packages = check_python_packages(venv_python)

  -- Install missing packages
  if not packages_ok then
    local success, err = install_packages(config, missing_packages)
    if not success then
      return false, err
    end
  end

  return true, ''
end

--- Get Python executable for railroad generation
---@param config? RegexplainerDepsConfig
---@param options? RegexplainerOptions
---@return string|nil python_cmd, string|nil error_msg
function M.get_python_cmd(config, options)
  config = vim.tbl_deep_extend('force', default_config, config or {})

  -- Check cache validity
  local now = os.time()
  if now - _cache.last_check < config.check_interval and _cache.python_cmd then
    return _cache.python_cmd, nil
  end

  -- Try user-specified python command first
  if config.python_cmd then
    local success, missing = check_python_packages(config.python_cmd)
    if success then
      _cache.python_cmd = config.python_cmd
      _cache.last_check = now
      return config.python_cmd, nil
    elseif not config.auto_install then
      return nil, string.format('Python packages missing: %s', table.concat(missing, ', '))
    end
  end

  -- Try system Python
  local system_python, version = find_python()
  if system_python then
    local success, missing = check_python_packages(system_python)
    if success then
      _cache.python_cmd = system_python
      _cache.last_check = now
      return system_python, nil
    elseif not config.auto_install then
      return nil, string.format('Python packages missing: %s', table.concat(missing, ', '))
    end
  end

  -- Try virtual environment
  if venv_exists(config) then
    local venv_python = get_venv_python_path(config)
    local success, missing = check_python_packages(venv_python)
    if success then
      _cache.python_cmd = venv_python
      _cache.last_check = now
      return venv_python, nil
    end
  end

  -- Auto-install if enabled
  if config.auto_install then
    if options and options.debug then
      utils.notify('Installing Python dependencies for graphical mode...', 'info')
    end

    local success, err = setup_venv(config)
    if success then
      local venv_python = get_venv_python_path(config)
      _cache.python_cmd = venv_python
      _cache.last_check = now

      if options and options.debug then
        utils.notify('Python dependencies installed successfully', 'info')
      end

      return venv_python, nil
    else
      return nil, err
    end
  end

  return nil, 'Python dependencies not available and auto_install is disabled'
end

--- Check dependency status for health check
---@param config? RegexplainerDepsConfig
---@return table status
function M.check_health(config)
  config = vim.tbl_deep_extend('force', default_config, config or {})

  local status = {
    python_found = false,
    python_version = nil,
    venv_exists = false,
    packages_available = false,
    missing_packages = {},
    venv_path = get_venv_path(config),
    error = nil,
  }

  -- Check system Python
  local python_cmd, version = find_python()
  if python_cmd then
    status.python_found = true
    status.python_version = version

    -- Check system packages
    local success, missing = check_python_packages(python_cmd)
    if success then
      status.packages_available = true
    else
      status.missing_packages = missing
    end
  end

  -- Check virtual environment
  status.venv_exists = venv_exists(config)
  if status.venv_exists then
    local venv_python = get_venv_python_path(config)
    local success, missing = check_python_packages(venv_python)
    if success then
      status.packages_available = true
      status.missing_packages = {}
    end
  end

  return status
end

--- Clear dependency cache (useful for testing)
function M.clear_cache()
  _cache = {
    last_check = 0,
    python_cmd = nil,
    venv_python = nil,
    deps_available = false,
    venv_exists = false,
  }
end

return M
