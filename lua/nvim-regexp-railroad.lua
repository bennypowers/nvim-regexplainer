local utils  = require'nvim-regexp-railroad.utils'
local module = require'nvim-regexp-railroad.module'

local M = {}

local default_config = {
  mappings = {
    RegexpRailroadShow = 'gR',
  },
}

-- setup is the public method to setup your plugin
M.setup = function(config)
  config = vim.tbl_deep_extend('keep', config or {}, default_config)

  for cmd, binding in pairs(config.mappings) do
    utils.map('n', binding, ':' .. cmd .. '<CR>')
  end
end

-- "show" is a public method for the plugin
M.show = function()
  module.show_below()
end

return M
