local module = require'nvim-regexp-railroad.module'

local M = {}

-- default config
local config = {
}

-- setup is the public method to setup your plugin
M.setup = function(args)
  config = vim.tbl_deep_extend('keep', args, config)
end

-- "show" is a public method for the plugin
M.show = function()
  if module.is_on_regexp() then
    module.show_below()
  end
end

return M
