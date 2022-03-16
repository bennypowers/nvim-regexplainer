-- Need the absolute path as when doing the testing we will issue things like `tcd` to change directory
-- to where our temporary filesystem lives
vim.opt.rtp = {
  vim.fn.fnamemodify(vim.trim(vim.fn.system("git rev-parse --show-toplevel")), ":p"),
  vim.env.VIMRUNTIME,
  vim.fn.expand('./vendor/plenary.nvim'),
  vim.fn.expand('./vendor/nvim-treesitter'),
  vim.fn.expand('./vendor/nui.nvim'),
}

vim.opt.swapfile = false

vim.cmd([[
  filetype on
  runtime plugin/regexplainer.vim
  runtime vendor/plenary.nvim
  runtime vendor/nui.nvim
  runtime vendor/nvim-treesitter
]])

require'nvim-treesitter.configs'.setup {}

-- For debugging
function P(...)
  print(unpack(vim.tbl_map(vim.inspect, { ... })))
end


