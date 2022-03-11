local utils   = require'regexplainer.utils'
local autocmd = require'nui.utils.autocmd'
local event   = autocmd.event

---@alias NuiBuffer NuiPopup|NuiSplit

---@class WindowOptions
---@field wrap         boolean
---@field conceallevel "0|1|2|3"

---@class BufferOptions
---@field filetype     string
---@field readonly     boolean
---@field modifiable   boolean

---@class NuiSplitBufferOptions: NuiBufferOptions
---@field relative "'editor'"|"'window'"
---@field position "'bottom'"|"'top'"
---@field size     string

---@class NuiBorderOptions
---@field padding number[]
---@field style   "'shadow'"|"'double'"

---@class NuiPopupBufferOptions: NuiBufferOptions
---@field relative "'cursor'"
---@field position number
---@field size     number|table<"'width'"|"'height'", number>
---@field border   NuiBorderOptions

---@alias RegexplainerBufferOptions NuiSplitBufferOptions|NuiPopupBufferOptions

local all_buffers = {}

-- TODO: remove this, or only store the last parent,
-- push and pop from all_buffers instead
local last = {
  parent = nil,
  split = nil,
  popup = nil,
}

---@class NuiBufferOptions
---@field enter       boolean
---@field focusable   boolean
---@field buf_options BufferOptions
---@field win_options WindowOptions
--
local shared_options = {
  enter = false,
  focusable = false,
  buf_options = {
    filetype = "Regexplainer",
    readonly = false,
    modifiable = true,
  },
  win_options = {
    wrap = true,
    conceallevel = 2,
  },
}

---@param object NuiBuffer
---@returns "'NuiSplit'"|"'NuiPopup'"
local function get_class_name(object)
  local passed, class_name = pcall(function()
    return getmetatable(getmetatable(object).__index).__name
  end)
  if passed then
    return class_name
  else
    utils.notify(class_name, 'error')
  end
end

---@param buffer NuiBuffer
local function is_popup(buffer)
  return get_class_name(buffer) == 'NuiPopup'
end

---@param buffer NuiBuffer
local function is_split(buffer)
  return get_class_name(buffer) == 'NuiSplit'
end

---@alias Timer any

---@type Timer
local last_timer

--- Closes the last timer and replaces it with the new one
---@param timer Timer
--
local function close_last_timer(timer)
  if last_timer then
    last_timer:close()
  end
  if timer and timer ~= last_timer then
    last_timer = timer
  end
end

-- Functions to create or modify the buffer which displays the regexplanation
--
local M = {}

--- Get the buffer in which to render the explainer
---@param options RegexplainerOptions
---@return NuiPopup|NuiSplit
--
function M.get_buffer(options)
  last.parent = {
    winnr = vim.api.nvim_get_current_win(),
    bufnr = vim.api.nvim_get_current_buf(),
  }

  ---@type NuiBuffer
  local buffer

  if options.display == 'split' then
    if last.split then
      return last.split
    end
    buffer = require'nui.split'(vim.tbl_deep_extend('keep', shared_options, {
      relative = 'editor',
      position = 'bottom',
      size = '20%',
    }))
    last.split = buffer

  elseif options.display == 'popup' then
    if last.popup then return last.popup end
    buffer = require'nui.popup'(vim.tbl_deep_extend('keep', shared_options, {
      position = 1,
      relative = 'cursor',
      size = 1,
      border = (options and options.popup and options.popup.border) or {
        padding = { 1, 2 },
        style = 'shadow',
      },
    }))
    last.popup = buffer
  end

  table.insert(all_buffers, buffer);

  return buffer
end

---@param buffer NuiBuffer
---@param renderer RegexplainerRenderer
---@param options RegexplainerOptions
---@param components RegexplainerComponent[]
--
function M.render(buffer, renderer, options, components)
  local lines = renderer.get_lines(components, options)

  local height = #lines
  if not buffer.mounted then
    buffer:mount()
  end

  if is_popup(buffer) then
    local win_width = vim.api.nvim_win_get_width(last.parent.winnr)

    local width = 0

    for _, line in ipairs(lines) do
      if #line > width then
        width = #line
      end
    end

    if (win_width * .75) < width then
      width = '75%'
    end

    buffer:set_size { width = width, height = height }

    buffer:on({
      event.BufLeave,
      event.BufWinLeave,
      event.CursorMoved,
    }, function ()
      M.kill_buffer(buffer)
    end, { once = true })
  end

  renderer.set_lines(buffer, lines)

  if is_split(buffer) then
    vim.api.nvim_set_current_win(last.parent.winnr)
    vim.api.nvim_set_current_buf(last.parent.bufnr)
    vim.api.nvim_win_set_height(buffer.winid, height)
  end

  autocmd.buf.define(last.parent.bufnr, {
    event.BufHidden,
    event.BufLeave,
  }, function ()
    M.kill_buffer(buffer)
  end)
end

--- Close and unload a buffer
---@param buffer NuiBuffer
--
function M.kill_buffer(buffer)
  -- pcall(close_last_timer)
  if buffer then
    pcall(function () buffer:hide() end)
    pcall(function () buffer:unmount() end)
    for i, buf in ipairs(all_buffers) do
      if buf == buffer then
        table.remove(all_buffers, i)
      end
    end
    for _, key in ipairs({ 'popup', 'split' }) do
      if last[key] == buffer then
        last[key] = nil
        last.parent = nil
      end
    end
  end
end

--- Hide the last-opened Regexplainer buffer
--
function M.hide_last()
  M.kill_buffer(last.popup)
  M.kill_buffer(last.split)
end

--- Hide all known Regexplainer buffers
--
function M.hide_all()
  for _, buffer in ipairs(all_buffers) do
    M.kill_buffer(buffer)
    last.parent = nil
    last.split = nil
    last.popup = nil
  end
end

--- Notify regarding all known Regexplainer buffers
--- **INTERNAL**: for debug purposes only
--
function M.debug_buffers()
  utils.notify(all_buffers)
  utils.notify(last)
end

--- Whether there are any open Regexplainer buffers
---@return boolean
--
function M.is_open()
  return #all_buffers > 0
end

--- **INTERNAL** Register a debounce timer,
--- so that we can close it to prevent memory leaks when closing buffers
---@param timer Timer
--
function M.register_timer(timer)
  pcall(close_last_timer, timer)
end

return M

