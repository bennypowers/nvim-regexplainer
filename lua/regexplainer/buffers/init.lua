local utils  = require 'regexplainer.utils'

local all_buffers = {}

-- TODO: remove this, or only store the last parent,
-- push and pop from all_buffers instead
local last = {
  parent = nil,
  split = nil,
  popup = nil,
}

---@param object RegexplainerBuffer
---@returns 'NuiSplit'|'NuiPopup'|'Scratch'
local function get_class_name(object)
  if object.type then
    return object.type
  else
    return getmetatable(getmetatable(object).__index).__name
  end
end

---@param expected 'NuiSplit'|'NuiPopup'|'Scratch'
---@return fun(buffer:RegexplainerBuffer):boolean
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
---@return RegexplainerBuffer
--
function M.get_buffer(options)
  options = options or {}

  local buffer

  local state = {
    last = last
  }

  if options.display == 'register' then
    buffer = require'regexplainer.buffers.register'.get_buffer(options, state)

  elseif options.display == 'split' then
    buffer = require'regexplainer.buffers.split'.get_buffer(options, state)

  elseif options.display == 'popup' then
    buffer = require'regexplainer.buffers.popup'.get_buffer(options, state)
  end

  table.insert(all_buffers, buffer);

  state.last.parent = {
    winnr = vim.api.nvim_get_current_win(),
    bufnr = vim.api.nvim_get_current_buf(),
  }

  return buffer
end

---@param buffer     RegexplainerBuffer
---@param renderer   RegexplainerRenderer
---@param options    RegexplainerRenderOptions
---@param components RegexplainerComponent[]
---@param state      RegexplainerRendererState
--
function M.render(buffer, renderer, components, options, state)
  state.last = last
  local lines = renderer.get_lines(components, options, state)
  buffer:init(lines, options, state)
  renderer.set_lines(buffer, lines)
  buffer:after(lines, options, state)
end

--- Close and unload a buffer
---@param buffer RegexplainerBuffer
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
---@type fun(buffer:RegexplainerBuffer):boolean
M.is_popup = is_buftype('NuiPopup')

---Is it a split buffer?
---@type fun(buffer:RegexplainerBuffer):boolean
M.is_split = is_buftype('NuiSplit')

---Is it a scratch buffer?
---@type fun(buffer:RegexplainerBuffer):boolean
M.is_scratch = is_buftype('Scratch')

return M
