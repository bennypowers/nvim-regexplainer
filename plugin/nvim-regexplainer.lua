vim .cmd [[
  command! RegexplainerShow lua require'nvim-regexplainer'.show()
  command! RegexplainerShowSplit lua require'nvim-regexplainer'.show({ display = 'split' })
  command! RegexplainerShowPopup lua require'nvim-regexplainer'.show({ display = 'popup' })
]]

