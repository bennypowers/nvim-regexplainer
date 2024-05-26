local Shared = require 'regexplainer.buffers.shared'
local Split = require 'nui.split'

local set_current_win = vim.api.nvim_set_current_win
local set_current_buf = vim.api.nvim_set_current_buf
local win_set_height = vim.api.nvim_win_set_height
local extend = vim.tbl_deep_extend

local M = {}

---@type NuiSplitBufferOptions
local split_defaults = {
  relative = 'editor',
  position = 'bottom',
  size = '20%',
}

local function after(self, lines, _, state)
  set_current_win(state.last.parent.winnr)
  set_current_buf(state.last.parent.bufnr)
  win_set_height(self.winid, #lines)
end

function M.get_buffer(options, state)
  if state.last.type == 'NuiSplit' then
    return state.last
  end
  local buffer = Split(extend('force', Shared.shared_options, split_defaults, options.split or {}))
  buffer.type = 'NuiSplit'
  state.last = buffer
  buffer.init = Shared.default_buffer_init
  buffer.after = after
  return buffer
end

return M
