-- For debugging
function P(...)
  print(unpack(vim.tbl_map(vim.inspect, { ... })))
end

vim.cmd([[
  set noswapfile
  filetype on
  runtime plugin/regexplainer.vim
]])

require'nvim-treesitter.configs'.setup {}

