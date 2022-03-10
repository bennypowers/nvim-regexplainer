local utils   = require'regexplainer.utils'
local autocmd = require'nui.utils.autocmd'
local event   = autocmd.event

-- Functions to create or modify the buffer which displays the regexplanation
--
local M = {}

local all_buffers = {}

-- TODO: remove this, or only store the last parent,
-- push and pop from all_buffers instead
local last = {
  parent = nil,
  split = nil,
  popup = nil,
}

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

local function is_popup(buffer)
  return get_class_name(buffer) == 'NuiPopup'
end

local function is_split(buffer)
  return get_class_name(buffer) == 'NuiSplit'
end

-- Get the buffer in which to render the explainer
--
function M.get_buffer(options)
  last.parent = {
    winnr = vim.api.nvim_get_current_win(),
    bufnr = vim.api.nvim_get_current_buf(),
  }
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
      win_options = (options and options.popup and options.popup.win_options) or {},
    }))
    last.popup = buffer
  end

  table.insert(all_buffers, buffer);

  return buffer
end

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

M.kill_buffer = function(buffer)
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

M.hide_last = function ()
  M.kill_buffer(last.popup)
  M.kill_buffer(last.split)
end

M.hide_all = function ()
  for _, buffer in ipairs(all_buffers) do
    M.kill_buffer(buffer)
    last.parent = nil
    last.split = nil
    last.popup = nil
  end
end

M.debug_buffers = function()
  utils.notify(all_buffers)
  utils.notify(last)
end

M.is_open = function ()
  return #all_buffers > 0
end

return M

