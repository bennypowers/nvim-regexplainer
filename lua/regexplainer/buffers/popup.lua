local Shared = require 'regexplainer.buffers.shared'

local M = {}

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

  local win_width = vim.api.nvim_win_get_width(state.last.parent.winnr)

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
    local function unmount() self:unmount() end
    local bufnr = state.last.parent.bufnr
    vim.api.nvim_create_autocmd('BufLeave', { buffer = bufnr, once = true, callback = unmount })
    self:on({ 'BufLeave', 'BufWinLeave', 'CursorMoved' }, unmount, { once = true })
  end
end

function M.get_buffer(options, state)
  if state.last.popup then
    return state.last.popup
  end

  local Popup = require 'nui.popup'

  local buffer = Popup(vim.tbl_deep_extend('force',
    Shared.shared_options,
    popup_defaults, options.popup or {}
  ) or popup_defaults)

  buffer.type = 'NuiPopup'

  state.last.popup = buffer

  buffer.init = init
  buffer.after = after

  return buffer
end

return M
