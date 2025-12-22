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

    -- Actually wait for the task to complete using pwait
    -- This processes the async event loop instead of just polling
    if task and task.pwait then
      local ok, err = task:pwait(120000)  -- 2 minutes per parser
      if not ok then
        error(string.format('Failed to install %s parser: %s', lang, err or 'unknown error'))
      end
    end

    -- pwait() can return before the file is fully written
    -- Poll for a short time to ensure the .so file exists
    local start = vim.loop.now()
    local file_wait_timeout = 5000  -- 5 seconds should be plenty
    while vim.fn.filereadable(parser_file) ~= 1 do
      if vim.loop.now() - start > file_wait_timeout then
        error(string.format('%s parser installation completed but .so file not found at %s after %ds',
          lang, parser_file, file_wait_timeout / 1000))
      end
      vim.wait(50)
    end

    print(lang .. ' parser installed')
  end
end

print('All parsers ready')
