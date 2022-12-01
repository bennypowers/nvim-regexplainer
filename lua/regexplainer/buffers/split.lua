local Shared = require 'regexplainer.buffers.shared'
local Split = require 'nui.split'

local M = {}

---@type NuiSplitBufferOptions
local split_defaults = {
  relative = 'editor',
  position = 'bottom',
  size = '20%',
}

local function after(self, lines, _, state)
  vim.api.nvim_set_current_win(state.last.parent.winnr)
  vim.api.nvim_set_current_buf(state.last.parent.bufnr)
  vim.api.nvim_win_set_height(self.winid, #lines)
end

function M.get_buffer(options, state)
  if state.last.split then
    return state.last.split
  end

  local buffer = Split(vim.tbl_deep_extend('force',
                                           Shared.shared_options,
                                           split_defaults,
                                           options.split or {}))

  buffer.type = 'NuiSplit'

  state.last.split = buffer

  buffer.init = Shared.default_buffer_init
  buffer.after = after

  vim.notify('split buf')
  return buffer
end

return M
