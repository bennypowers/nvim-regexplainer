vim .cmd [[
  command! RegexpRailroadShow lua require'nvim-regexp-railroad'.show()
]]

-- vim.cmd [[
--   augroup regexprailroad
--     autocmd!
--     autocmd CursorHold lua require'nvim-regexp-railroad'.show()
--   augroup END
-- ]]

