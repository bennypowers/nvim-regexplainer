local Shared = require 'regexplainer.buffers.shared'

local M = {}

local au = vim.api.nvim_create_autocmd
local get_win_width = vim.api.nvim_win_get_width
local extend = vim.tbl_deep_extend

---@type NuiPopupBufferOptions
local popup_defaults = {
  position = 2,
  relative = 'cursor',
  size = 1,
  border = {
    style = 'shadow',
    padding = { 1, 2 },
  },
}

local function init(self, lines, _, state)
  Shared.default_buffer_init(self)

  local win_width = get_win_width(state.last.parent.winnr)

  ---@type number|string
  local width = 0

  for _, line in ipairs(lines) do
    if #line > width then
      width = #line
    end
  end

  if (win_width * .75) < width then
    width = '75%'
  end

  self:set_size { width = width, height = #lines }
end

local function after(self, _, options, state)
  if options.auto then
    au({ 'BufLeave', 'BufWinLeave', 'CursorMoved' }, {
      buffer = state.last.parent.bufnr,
      once = true,
      callback = function() self:unmount() end,
    })
  end
end

function M.get_buffer(options, state)
  local Popup = require'nui.popup'
  local buffer = Popup(extend('force',
    Shared.shared_options,
    popup_defaults, options.popup or {}
  ) or popup_defaults)
  buffer.type = 'NuiPopup'
  state.last = buffer
  buffer.init = init
  buffer.after = after
  return buffer
end

return M
