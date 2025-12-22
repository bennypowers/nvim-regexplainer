local Setup = require 'tests.setup'

Setup.load 'MunifTanjim/nui.nvim'
Setup.load 'nvim-lua/plenary.nvim'
Setup.load 'nvim-treesitter/nvim-treesitter'

Setup.setup()

local parsers = { 'html', 'javascript', 'typescript', 'regex' }

-- Setup is already called in Setup.setup(), so install_dir is configured
-- Just verify the config
local config = require('nvim-treesitter.config')
local parser_dir = config.get_install_dir('parser')
print('Parser install directory: ' .. parser_dir)

-- Install parsers using the async API, but poll for actual file existence
local install = require('nvim-treesitter.install')

for _, lang in ipairs(parsers) do
  local parser_file = parser_dir .. '/' .. lang .. '.so'

  if vim.fn.filereadable(parser_file) ~= 1 then
    print('Installing ' .. lang .. '...')

    -- Start async installation
    local task = install.install({ lang }, { summary = false })

    -- We need to keep the async task running by either:
    -- 1. Calling task:wait() to process the event loop, OR
    -- 2. Manually processing events with vim.wait()
    --
    -- The task won't complete until we yield control.
    -- So we wait on the task itself, then verify the file exists
    if task and task.wait then
      task:wait(30000)  -- This processes async events
    end

    -- Now verify the file actually exists
    if vim.fn.filereadable(parser_file) ~= 1 then
      error(string.format('%s parser .so file not found at %s', lang, parser_file))
    end

    print(lang .. ' parser installed')
  end
end

print('All parsers ready')
