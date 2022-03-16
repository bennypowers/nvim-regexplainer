-- Need the absolute path as when doing the testing we will issue things like `tcd` to change directory
-- to where our temporary filesystem lives
vim.opt.rtp = {
  vim.fn.fnamemodify(vim.trim(vim.fn.system("git rev-parse --show-toplevel")), ":p"),
  vim.env.VIMRUNTIME,
}

vim.opt.swapfile = false

vim.cmd([[
  filetype on
  packadd plenary.nvim
  packadd nui.nvim
  packadd nvim-treesitter
  runtime plugin/regexplainer.vim
]])

require'nvim-treesitter.configs'.setup {}

-- For debugging
function P(...)
  print(unpack(vim.tbl_map(vim.inspect, { ... })))
end

