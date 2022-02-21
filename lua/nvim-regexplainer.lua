local utils  = require'nvim-regexplainer.util.utils'
local module = require'nvim-regexplainer.module'

local M = {}

local config_command_map = {
  show = 'RegexplainerShow',
}

local config_command_description_map = {
  show = 'Explain the regexp under the cursor',
}

local default_config = {
  -- 'narrative'
  mode = 'narrative', -- TODO: 'ascii', 'graphical'

  -- automatically show the explainer when the cursor enters a regexp
  auto = false,

  -- 'split', 'popup'
  display = 'popup',

  mappings = {
    show = 'gR',
  },

  narrative = {
    separator = '\n',
  },
}

local local_config = default_config

-- merge in the user config and setup key bindings
M.setup = function(config)
  local_config = vim.tbl_deep_extend('keep', config or {}, default_config)
  local has_which_key, wk = pcall(require, 'which-key')
  for cmd, binding in pairs(local_config.mappings) do
    local command = ':' .. config_command_map[cmd] .. '<CR>'

    if has_which_key then
      local description = config_command_description_map[cmd]
      wk.register({ [binding] = { command, description } }, { mode = 'n' })
    else
      utils.map('n', binding, command)
    end
  end
  if local_config.auto then
    vim.cmd [[
      augroup Regexplainer
        function RegexplainerDelayed(...)
          :RegexplainerShow
        endfunction
        autocmd CursorMoved *.html,*.js,*.ts call timer_start(1, 'RegexplainerDelayed')
      augroup END
    ]]
  end
end

-- "show" is a public method for the plugin
M.show = function(config)
  module.show(vim.tbl_deep_extend('keep', config or {}, local_config))
end

return M
