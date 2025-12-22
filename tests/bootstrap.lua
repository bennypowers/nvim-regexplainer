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

    -- Start async installation (don't rely on :wait() - it's broken in CI)
    install.install({ lang }, { summary = false })

    -- Poll for completion by checking if the .so file exists
    -- This is more reliable than :wait() in CI
    local start = vim.loop.now()
    local timeout = 60000  -- 60 seconds per parser

    while vim.fn.filereadable(parser_file) ~= 1 do
      if vim.loop.now() - start > timeout then
        error(string.format('Timeout: %s parser not installed after %ds', lang, timeout / 1000))
      end
      vim.wait(100)
    end

    print(lang .. ' parser installed')
  end
end

print('All parsers ready')
