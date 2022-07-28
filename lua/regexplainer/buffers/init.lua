local utils   = require 'regexplainer.utils'
local autocmd = require 'nui.utils.autocmd'
local event   = autocmd.event
local Scratch = require 'regexplainer.buffers.scratch'

---@class NuiBuffer: ScratchBuffer|NuiPopup|NuiSplit
---@field type       "NuiPopup"|"NuiSplit"|"Scratch"

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

---@type NuiSplitBufferOptions
local split_defaults = {
  relative = 'editor',
  position = 'bottom',
  size = '20%',
}

---@type NuiPopupBufferOptions
local popup_defaults = {
  position = 1,
  relative = 'cursor',
  size = 1,
  border = {
    style = 'shadow',
    padding = { 1, 2 },
  },
}

---@param object NuiBuffer
---@returns "'NuiSplit'"|"'NuiPopup'"|"'Scratch'"
local function get_class_name(object)
  if object.type then
    return object.type
  else
    return getmetatable(getmetatable(object).__index).__name
  end
end

---@param expected "'NuiSplit'"|"'NuiPopup'"|"'Scratch'"
---@returns function(buffer: NuiBuffer): boolean
local function is_buftype(expected)
  return function(buffer)
    local passed, classname = pcall(get_class_name, buffer)
    return passed and classname == expected
  end
end

---@alias Timer any

---@type Timer[]
local timers = {}

--- Closes all timers
--
local function close_timers()
  for _, timer in ipairs(timers) do
    timer:close()
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
  options = options or {}

  local buffer

  if options.display == 'pasteboard' then
    -- Create scratch buffer
    buffer = Scratch({})
    buffer.type = 'Scratch'

  elseif options.display == 'split' then
    if last.split then return last.split end
    local Split = require 'nui.split'
    buffer = Split(vim.tbl_deep_extend('force', shared_options, split_defaults, options.split or {}) or
      split_defaults)
    buffer.type = 'NuiSplit'
    last.split = buffer

  elseif options.display == 'popup' then
    if last.popup then return last.popup end
    local Popup = require 'nui.popup'
    buffer = Popup(vim.tbl_deep_extend('force', shared_options, popup_defaults, options.popup or {}) or
      popup_defaults)
    buffer.type = 'NuiPopup'
    last.popup = buffer
  end

  table.insert(all_buffers, buffer);

  last.parent = {
    winnr = vim.api.nvim_get_current_win(),
    bufnr = vim.api.nvim_get_current_buf(),
  }

  return buffer
end

---@param buffer NuiBuffer
---@param renderer   RegexplainerRenderer
---@param options    RegexplainerOptions
---@param components RegexplainerComponent[]
---@param state      RegexplainerRendererState
--
function M.render(buffer, renderer, options, components, state)
  local lines = renderer.get_lines(components, options, state)

  local height = #lines

  if not buffer._.mounted then
    buffer:mount()
  end

  if M.is_popup(buffer) then
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

    if options.auto then
      buffer:on({
        event.BufLeave,
        event.BufWinLeave,
        event.CursorMoved
      }, function()
        M.kill_buffer(buffer)
      end, { once = true })
    end
  end

  renderer.set_lines(buffer, lines)

  if M.is_split(buffer) then
    vim.api.nvim_set_current_win(last.parent.winnr)
    vim.api.nvim_set_current_buf(last.parent.bufnr)
    vim.api.nvim_win_set_height(buffer.winid, height)
  end

  if M.is_scratch(buffer) then
    buffer:yank('*')
    M.kill_buffer(buffer)

  elseif options.auto then
    autocmd.buf.define(last.parent.bufnr, {
      event.BufHidden,
      event.BufLeave,
    }, function()
      M.kill_buffer(buffer)
    end)
  end

end

--- Close and unload a buffer
---@param buffer NuiBuffer
--
function M.kill_buffer(buffer)
  if buffer then
    pcall(function() buffer:hide() end)
    pcall(function() buffer:unmount() end)
    for i, buf in ipairs(all_buffers) do
      if buf == buffer then
        table.remove(all_buffers, i)
      end
    end
    for _, key in ipairs({ 'popup', 'split' }) do
      if last[key] == buffer then
        last[key] = nil
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
    last.split = nil
    last.popup = nil
  end
end

--- Notify regarding all known Regexplainer buffers
--- **INTERNAL**: for debug purposes only
---@private
--
function M.debug_buffers()
  utils.notify(all_buffers)
  utils.notify(last)
end

--- get all active regexplaine buffers
--- **INTERNAL**: for debug purposes only
---@private
--
function M.get_buffers()
  return all_buffers
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
  table.insert(timers, timer)
end

--- **INTERNAL** clear timers
--
function M.clear_timers()
  pcall(close_timers)
end

---Is it a popup buffer?
---@param buffer NuiBuffer
---@return boolean
M.is_popup = is_buftype('NuiPopup')

---Is it a split buffer?
---@param buffer NuiBuffer
---@return boolean
M.is_split = is_buftype('NuiSplit')

---Is it a scratch buffer?
---@param buffer NuiBuffer
---@return boolean
M.is_scratch = is_buftype('Scratch')

return M
