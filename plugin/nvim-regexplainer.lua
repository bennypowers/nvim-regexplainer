local function lazy(fn)
  return function(args)
    require('regexplainer')[fn](args and args.args ~= '' and args.args or nil)
  end
end

local command = vim.api.nvim_create_user_command

command('RegexplainerShow',      lazy 'show',      { bang = true })
command('RegexplainerHide',      lazy 'hide',      { bang = true })
command('RegexplainerToggle',    lazy 'toggle',    { bang = true })
command('RegexplainerYank',      lazy 'yank',      { bang = true, nargs = '*' })
command('RegexplainerShowSplit', lazy 'show_split', { bang = true })
command('RegexplainerShowPopup', lazy 'show_popup', { bang = true })
command('RegexplainerDebug',     lazy 'debug_components', { bang = true })
command('RegexplainerClearCache', lazy 'clear_cache', { bang = true })
