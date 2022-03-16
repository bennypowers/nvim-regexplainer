-- For debugging
function P(...)
  print(unpack(vim.tbl_map(vim.inspect, { ... })))
end

vim.cmd([[
  set noswapfile
  set rtp+=./vendor/plenary.nvim
  set rtp+=./vendor/nvim-treesitter
  set rtp+=./vendor/nui.nvim
  filetype on
  packadd plenary.nvim
  packadd nui.nvim
  packadd nvim-treesitter
  runtime plugin/regexplainer.vim
]])

require'nvim-treesitter.configs'.setup {}

