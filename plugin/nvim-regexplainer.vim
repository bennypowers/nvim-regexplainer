command! RegexplainerShow      :lua require'regexplainer'.show()
command! RegexplainerShowHide  :lua require'regexplainer'.hide()
command! RegexplainerShowSplit :lua require'regexplainer'.show { display = 'split' }
command! RegexplainerShowPopup :lua require'regexplainer'.show { display = 'popup' }
