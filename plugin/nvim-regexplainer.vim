command! RegexplainerShow      :lua require'regexplainer'.show()
command! RegexplainerShowSplit :lua require'regexplainer'.show({ display = 'split' })
command! RegexplainerShowPopup :lua require'regexplainer'.show({ display = 'popup' })
