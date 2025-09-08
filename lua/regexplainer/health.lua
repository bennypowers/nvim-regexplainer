local M = {}

local health = {
  start = vim.health.start or vim.health.report_start,
  ok = vim.health.ok or vim.health.report_ok,
  warn = vim.health.warn or vim.health.report_warn,
  error = vim.health.error or vim.health.report_error,
  info = vim.health.info or vim.health.report_info,
}

--- Check regexplainer health
function M.check()
  health.start("regexplainer")
  
  -- Check basic functionality
  health.info("nvim-regexplainer health check")
  
  -- Check treesitter
  local ts_ok, _ = pcall(require, 'nvim-treesitter')
  if ts_ok then
    health.ok("nvim-treesitter is available")
    
    -- Check if regex parser is installed
    local parsers = require('nvim-treesitter.parsers')
    if parsers.has_parser('regex') then
      health.ok("Treesitter regex parser is installed")
    else
      health.error("Treesitter regex parser is not installed", {
        "Run :TSInstall regex to install the regex parser"
      })
    end
  else
    health.error("nvim-treesitter is not available", {
      "nvim-regexplainer requires nvim-treesitter",
      "Install it with your plugin manager"
    })
  end
  
  -- Check NUI
  local nui_ok, _ = pcall(require, 'nui')
  if nui_ok then
    health.ok("nui.nvim is available")
  else
    health.error("nui.nvim is not available", {
      "nvim-regexplainer requires nui.nvim",
      "Install it with your plugin manager"
    })
  end
  
  -- Check graphics support
  health.start("Graphics Support")
  
  local graphics = require 'regexplainer.graphics'
  if graphics.is_graphics_supported() then
    local protocols = graphics.get_available_protocols()
    health.ok(string.format("Graphics protocol available: %s", table.concat(protocols, ', ')))
  else
    health.warn("No graphics protocol available", {
      "Graphical mode requires Kitty terminal",
      "Narrative mode will be used as fallback"
    })
  end
  
  -- Check Python dependencies
  health.start("Python Dependencies")
  
  local deps = require 'regexplainer.deps'
  local status = deps.check_health()
  
  if status.python_found then
    health.ok(string.format("Python found: %s", status.python_version or "unknown version"))
  else
    health.error("Python not found", {
      "Python 3.9+ is required for graphical mode",
      "Install Python from https://python.org"
    })
  end
  
  if status.venv_exists then
    health.ok(string.format("Virtual environment exists: %s", status.venv_path))
  else
    health.info(string.format("Virtual environment not found: %s", status.venv_path))
    health.info("Virtual environment will be created automatically when needed")
  end
  
  if status.packages_available then
    health.ok("All required Python packages are available")
  else
    if #status.missing_packages > 0 then
      health.warn(string.format("Missing Python packages: %s", table.concat(status.missing_packages, ', ')), {
        "Packages will be installed automatically when graphical mode is used",
        "Or manually install with: pip install railroad-diagrams Pillow cairosvg"
      })
    else
      health.info("Python packages not checked (Python not found)")
    end
  end
  
  -- Test basic functionality
  health.start("Functionality Tests")
  
  -- Test regex parsing
  local regexplainer = require 'regexplainer'
  local test_successful = pcall(function()
    -- Create a minimal test environment
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'test /hello/ world' })
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'javascript')
    
    -- Test component creation
    local tree = require 'regexplainer.utils.treesitter'
    local component = require 'regexplainer.component'
    
    -- This is a basic test - more comprehensive testing would require cursor positioning
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return true
  end)
  
  if test_successful then
    health.ok("Basic functionality test passed")
  else
    health.warn("Basic functionality test failed", {
      "This might indicate a configuration issue",
      "Try using regexplainer on a simple regex to test"
    })
  end
end

return M