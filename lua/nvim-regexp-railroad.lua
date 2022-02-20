local utils  = require'nvim-regexp-railroad.util.utils'
local module = require'nvim-regexp-railroad.module'

local M = {}

local config_command_map = {
  show = 'RegexpRailroadShow',
}

local default_config = {
  -- 'narrative'
  mode = 'narrative', -- TODO: 'ascii', 'graphical'

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
  for cmd, binding in pairs(local_config.mappings) do
    local command = ':' .. config_command_map[cmd] .. '<CR>'
    utils.map('n', binding, command)
  end
end

-- "show" is a public method for the plugin
M.show = function()
  module.show(local_config)
end

return M
