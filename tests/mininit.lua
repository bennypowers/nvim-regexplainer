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

local langs = {
  'html',
  'javascript',
  'typescript',
  'regex',
}

function M.setup()
  vim.cmd [[
    set noswapfile
    filetype on
    set runtimepath=$VIMRUNTIME
    runtime plugin/regexplainer.lua
  ]]

  local parser_install_dir = M.root '.tests/site'
  vim.opt.runtimepath:prepend(parser_install_dir)
  vim.opt.runtimepath:append(M.root())
  vim.opt.runtimepath:append(M.root 'tests')
  vim.opt.packpath = { M.root '.tests/site' }

  M.load 'MunifTanjim/nui.nvim'
  M.load 'nvim-lua/plenary.nvim'
  M.load 'nvim-treesitter/nvim-treesitter'

  vim.cmd [[packloadall]]

  -- Configure parser install directory for nvim-treesitter
  -- Try modern API first (nvim-treesitter.setup with install_dir)
  local ok, ts = pcall(require, 'nvim-treesitter')
  if ok and ts.setup then
    pcall(ts.setup, {
      install_dir = parser_install_dir,
    })
  end

  -- Fallback to old API for backward compatibility
  local ok_old, configs = pcall(require, 'nvim-treesitter.configs')
  if ok_old and configs.setup then
    pcall(configs.setup, {
      parser_install_dir = parser_install_dir,
    })
  end

  -- Install parsers (TSInstall! is idempotent and non-interactive)
  for _, lang in ipairs(langs) do
    pcall(vim.cmd, 'TSInstall! ' .. lang)
  end

  -- Wait for async installation to complete
  vim.wait(2000, function() return false end)
end

M.setup()
