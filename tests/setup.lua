local Setup = {}

function Setup.root(root)
  local f = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(f, ':p:h:h') .. '/' .. (root or '')
end

Setup.parser_install_dir = Setup.root '.tests/site'

function Setup.setup()
  vim.opt.swapfile = false
  vim.opt.filetype = 'on'
  vim.opt.packpath = { Setup.parser_install_dir }

  -- Add all pack/*/start/* directories to runtimepath for plugin files
  local pack_start = Setup.parser_install_dir .. '/pack/deps/start'
  vim.opt.runtimepath = {
    Setup.parser_install_dir,
    pack_start .. '/nvim-treesitter',
    pack_start .. '/plenary.nvim',
    pack_start .. '/nui.nvim',
    '$VIMRUNTIME',
    Setup.root(),
    Setup.root 'tests',
  }

  vim.cmd.runtime 'plugin/regexplainer.lua'
  vim.cmd.packloadall()
  local ts = require 'nvim-treesitter'
  ts.setup { install_dir = Setup.parser_install_dir }
end

---@param plugin string
function Setup.load(plugin)
  local name = plugin:match '.*/(.*)'
  local package_root = Setup.root '.tests/site/pack/deps/start/'
  if not vim.uv.fs_stat(package_root .. name) then
    print('Installing ' .. plugin)
    vim.fn.mkdir(package_root, 'p')
    vim.fn.system {
      'git',
      'clone',
      '--depth=1',
      'https://github.com/' .. plugin .. '.git',
      package_root .. '/' .. name,
    }
  end
end

return Setup
