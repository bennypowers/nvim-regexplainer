local function command (name, callback, options)
  local final_opts = vim.tbl_deep_extend('force', options or {}, { bang = true })
  vim.api.nvim_create_user_command(name, callback, final_opts)
end

local regexplainer = require'regexplainer'

command('RegexplainerShow',   function () regexplainer.show() end)
command('RegexplainerHide',   function () regexplainer.hide() end)
command('RegexplainerToggle', function () regexplainer.toggle() end)

command('RegexplainerYank',   function (args)
  regexplainer.yank(args.args)
end, {
  nargs = '*'
})

command('RegexplainerShowSplit', function () regexplainer.show {
  display = 'split',
} end)

command('RegexplainerShowPopup', function () regexplainer.show {
  display = 'popup',
} end)

command('RegexplainerDebug', function () regexplainer.show {
  display = 'split',
  mode = 'debug',
  auto = false,
} end)
