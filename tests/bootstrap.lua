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

    -- Start async installation and wait for completion
    local task = install.install({ lang }, { summary = false })

    if task and task.pwait then
      local ok, err = task:pwait(30000)  -- Max 30 seconds per parser (way more than needed)
      if not ok then
        error(string.format('Failed to install %s parser: %s', lang, err or 'unknown error'))
      end
    end

    -- Give the event loop one tick to flush any pending file writes
    vim.wait(100)

    -- Verify the file exists
    if vim.fn.filereadable(parser_file) ~= 1 then
      error(string.format('%s parser .so file not found at %s', lang, parser_file))
    end

    print(lang .. ' parser installed')
  end
end

print('All parsers ready')
