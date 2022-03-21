vim.cmd([[
  set rtp+=.
  set noswapfile
  filetype on
  packloadall
  runtime plugin/regexplainer.vim
]])

local did, configs = pcall(require, 'nvim-treesitter.configs')
if not did then print(configs) end

configs.setup {}

