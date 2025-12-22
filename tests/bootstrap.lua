local Setup = require 'tests.setup'

Setup.load 'MunifTanjim/nui.nvim'
Setup.load 'nvim-lua/plenary.nvim'
Setup.load 'nvim-treesitter/nvim-treesitter'

Setup.setup()

local parsers = { 'html', 'javascript', 'typescript', 'regex' }

local MAX_WAIT = 120000

local ts = require 'nvim-treesitter'
ts.setup { install_dir = Setup.parser_install_dir }

-- Start installation asynchronously
local task = ts.install(parsers)

-- Wait for installation with timeout (CI may have issues with :wait())
if task and task.wait then
  task:wait(MAX_WAIT)
end

-- Additional safety: poll until all parser .so files actually exist
-- This ensures parsers are ready regardless of :wait() behavior
local start_time = vim.loop.now()

while true do
  local all_ready = true
  for _, lang in ipairs(parsers) do
    local parser_file = Setup.parser_install_dir .. '/parser/' .. lang .. '.so'
    if vim.fn.filereadable(parser_file) ~= 1 then
      all_ready = false
      break
    end
  end

  if all_ready then
    break
  end

  if vim.loop.now() - start_time > MAX_WAIT then
    error('Timeout: parsers not installed after 60s. Check ' .. Setup.parser_install_dir .. '/parser/')
  end

  vim.wait(100) -- Check every 100ms
end
