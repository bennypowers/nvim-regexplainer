local utils   = require'nvim-regexplainer.util.utils'
local autocmd = require'nui.utils.autocmd'
local event   = autocmd.event

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
    conceallevel = 3,
  },
}

local last_split

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

-- Functions to create or modify the buffer which displays the regexplanation
--
local M = {}

-- Get the buffer in which to render the explainer
--
function M.get_buffer(options, parent)
  local buffer
  if options.display == 'split' then
    if last_split then return last_split end
    buffer = require'nui.split'(vim.tbl_deep_extend('keep', shared_options, {
      relative = 'editor',
      position = 'bottom',
      size = '20%',
    }))
    last_split = buffer
  elseif options.display == 'popup' then
    buffer = require'nui.popup'(vim.tbl_deep_extend('keep', shared_options, {
      position = 1,
      relative = 'cursor',
      size = {
        width = '75%',
        height = 5,
      },
      border = {
        padding = { 1, 2 },
        style = 'shadow',
      },
    }))
  end

  setmetatable(buffer, vim.tbl_deep_extend('keep', getmetatable(buffer), parent))

  return buffer
end

function M.finalize(buffer)
  local count = vim.api.nvim_buf_line_count(buffer.bufnr)
  local parent = getmetatable(buffer).parent

  if is_split(buffer) then
    buffer:on(event.BufUnload, function()
      last_split = nil
    end)
    vim.api.nvim_win_set_height(buffer.winid, count)
  end

  if is_popup(buffer) then
    buffer:set_size {
      width = '75%',
      height = count,
    }
    autocmd.buf.define(parent.bufnr, event.CursorMoved, function()
      buffer:unmount()
    end, { once = true })
  end

  vim.api.nvim_set_current_win(parent.winnr)
  vim.api.nvim_set_current_buf(parent.bufnr)

  vim.api.nvim_buf_call(parent.bufnr, function()
    buffer:on({ event.BufLeave, event.BufWinLeave }, function ()
      vim.schedule(function()
        buffer:hide()
        buffer:unmount()
      end)
    end, { once = true })
  end)
end

return M

