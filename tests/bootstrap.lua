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

    -- pwait() just waits for the task to "complete", but the task completes
    -- when compilation STARTS, not when it finishes. So we can't trust it.
    -- Instead, just poll for the .so file to appear (which means compilation finished)
    local timeout = 30000  -- 30 seconds should be way more than needed
    local ok = vim.wait(timeout, function()
      return vim.fn.filereadable(parser_file) == 1
    end, 100)

    if not ok then
      error(string.format('%s parser .so file not found after %ds', lang, timeout / 1000))
    end

    print(lang .. ' parser installed')
  end
end

print('All parsers ready')
