local M = {}

function M.root(root)
  local f = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(f, ':p:h:h') .. '/' .. (root or '')
end

---@param plugin string
function M.load(plugin)
  local name = plugin:match '.*/(.*)'
  local package_root = M.root '.tests/site/pack/deps/start/'
  if not vim.loop.fs_stat(package_root .. name) then
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

function M.setup()
  local parser_install_dir = M.root '.tests/site'

  vim.opt.swapfile = false
  vim.opt.filetype = 'on'
  vim.opt.packpath = { parser_install_dir }

  -- Add all pack/*/start/* directories to runtimepath for plugin files
  local pack_start = parser_install_dir .. '/pack/deps/start'
  vim.opt.runtimepath = {
    parser_install_dir,
    pack_start .. '/nvim-treesitter',
    pack_start .. '/plenary.nvim',
    pack_start .. '/nui.nvim',
    '$VIMRUNTIME',
    M.root(),
    M.root 'tests',
  }

  vim.cmd.runtime 'plugin/regexplainer.lua'

  M.load 'MunifTanjim/nui.nvim'
  M.load 'nvim-lua/plenary.nvim'
  M.load 'nvim-treesitter/nvim-treesitter'

  vim.cmd.packloadall()

  -- Ensure nvim-treesitter plugin files are loaded (for language registration)
  vim.cmd.runtime 'plugin/nvim-treesitter.lua'

  -- Configure parser install directory for nvim-treesitter
  local ok, ts = pcall(require, 'nvim-treesitter')

  if not ok then
    print 'Could not set up tree sitter'
    os.exit(1)
  end

  ts.setup { install_dir = parser_install_dir }

  local parsers = {
    'html',
    'javascript',
    'typescript',
    'regex',
  }

  for _, lang in ipairs(parsers) do
    if not pcall(function()
      ts.install(lang):wait(300000)
    end) then
      print('Failed to install language parser: ' .. lang)
    end
  end
end

M.setup()
