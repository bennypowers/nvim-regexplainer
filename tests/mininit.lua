-- For debugging
function P(...)
  print(unpack(vim.tbl_map(vim.inspect, { ... })))
end

vim.cmd([[
  set rtp+=.
  set noswapfile
  filetype on
  packloadall
  runtime plugin/regexplainer.vim
]])

require'nvim-treesitter.configs'.setup {}

