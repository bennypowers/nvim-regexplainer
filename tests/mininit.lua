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
  vim.opt.runtimepath = {
    parser_install_dir,
    '$VIMRUNTIME',
    M.root(),
    M.root 'tests',
  }

  vim.cmd.runtime 'plugin/regexplainer.lua'

  M.load 'MunifTanjim/nui.nvim'
  M.load 'nvim-lua/plenary.nvim'
  M.load 'nvim-treesitter/nvim-treesitter'

  vim.cmd.packloadall()

  -- Configure parser install directory for nvim-treesitter
  -- Try modern API first (nvim-treesitter.setup with install_dir)
  local ok, ts = pcall(require, 'nvim-treesitter')
  if ok and ts.setup then
    ok = pcall(ts.setup, {
      install_dir = parser_install_dir,
    })
  end

  if not ok then
    print 'Could not set up tree sitter'
    process:exit(1)
  end

  ts.install({
    'html',
    'javascript',
    'typescript',
    'regex',
  }):wait(300000)
end

M.setup()
