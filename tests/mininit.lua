local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

---@param plugin string
function M.load(plugin)
  local name = plugin:match(".*/(.*)")
  local package_root = M.root(".tests/site/pack/deps/start/")
  if not vim.loop.fs_stat(package_root .. name) then
    print("Installing " .. plugin)
    vim.fn.mkdir(package_root, "p")
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/" .. plugin .. ".git",
      package_root .. "/" .. name,
    })
  end
end

local langs = {
  'html',
  'javascript',
  'typescript',
  'regex',
}

function M.setup()
  vim.cmd([[
    set noswapfile
    filetype on
    set runtimepath=$VIMRUNTIME
    runtime plugin/regexplainer.vim
  ]])

  vim.opt.runtimepath:append(M.root())
  vim.opt.packpath = { M.root(".tests/site") }

  M.load("MunifTanjim/nui.nvim")
  M.load("nvim-lua/plenary.nvim")
  M.load("nvim-treesitter/nvim-treesitter")

  local parser_install_dir = M.root(".tests/share/treesitter");
  vim.opt.runtimepath:append(parser_install_dir)

  vim.cmd[[packloadall]]

  require 'nvim-treesitter.configs'.setup {
    parser_install_dir = parser_install_dir,
  }

  for _, lang in ipairs(langs) do
    if not require'nvim-treesitter.parsers'.has_parser(lang) then
      vim.cmd('TSInstallSync ' .. lang)
    end
  end
end

M.setup()

