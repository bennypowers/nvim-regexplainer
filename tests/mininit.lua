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

  local parser_install_dir = M.root '.tests/share/treesitter'
  vim.opt.runtimepath:append(parser_install_dir)
  vim.opt.runtimepath:append(M.root())
  vim.opt.runtimepath:append(M.root 'tests')
  vim.opt.packpath = { M.root '.tests/site' }

  M.load 'MunifTanjim/nui.nvim'
  M.load 'nvim-lua/plenary.nvim'
  M.load 'nvim-treesitter/nvim-treesitter'

  vim.cmd [[packloadall]]

  -- Initialize nvim-treesitter to make commands available
  pcall(require, 'nvim-treesitter')

  -- Configure parser install directory (for compatibility with older versions)
  local ok, configs = pcall(require, 'nvim-treesitter.configs')
  if ok and configs.setup then
    pcall(configs.setup, {
      parser_install_dir = parser_install_dir,
    })
  end

  -- Install parsers using the command if available, otherwise use the API
  for _, lang in ipairs(langs) do
    local install_ok = pcall(vim.cmd, 'TSInstallSync ' .. lang)
    if not install_ok then
      -- Fallback to direct API if command doesn't exist
      local install = pcall(require, 'nvim-treesitter.install')
      if install then
        pcall(require('nvim-treesitter.install').update, { with_sync = true }, lang)
      end
    end
  end
end

M.setup()
