command! RegexplainerShow        :lua require'regexplainer'.show()
command! RegexplainerHide        :lua require'regexplainer'.hide()
command! RegexplainerToggle      :lua require'regexplainer'.toggle()
command! RegexplainerShowSplit   :lua require'regexplainer'.show { display = 'split' }
command! RegexplainerShowPopup   :lua require'regexplainer'.show { display = 'popup' }
command! RegexplainerDebug       :lua require'regexplainer'.show { display = 'split', mode = 'debug', auto = false }
