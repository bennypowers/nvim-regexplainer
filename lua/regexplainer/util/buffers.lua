local utils   = require'regexplainer.util.utils'
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
local last_popup

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
    if last_popup then return last_popup end
    buffer = require'nui.popup'(vim.tbl_deep_extend('keep', shared_options, {
      position = 1,
      relative = 'cursor',
      size = 1,
      border = {
        padding = { 1, 2 },
        style = 'shadow',
      },
    }))
    last_popup = buffer
  end

  setmetatable(buffer, vim.tbl_deep_extend('keep', getmetatable(buffer), parent))

  return buffer
end

function M.render(buffer, renderer, renderer_options, components)
  local parent = getmetatable(buffer).parent

  if not buffer.mounted then
    buffer:mount()
  end

  if is_popup(buffer) then
    buffer:hide()
  end

  local lines = renderer.get_lines(components, renderer_options)

  local height = #lines
  local width = 0

  for _, line in ipairs(lines) do
    if #line > width then
      width = #line
    end
  end

  if is_split(buffer) then
    buffer:on(event.BufUnload, function()
      last_split = nil
    end)
    vim.api.nvim_win_set_height(buffer.winid, height)
  end

  if is_popup(buffer) then
    local win_width = vim.api.nvim_win_get_width(buffer.winid)

    if (win_width * .75) < width then
      width = '75%'
    end

    buffer:set_size { width = width, height = height }

    autocmd.buf.define(parent.bufnr, event.CursorMoved, function()
      -- buffer:unmount()
      buffer:hide()
    end, { once = true })

  end

  renderer.set_lines(buffer, lines)

  vim.api.nvim_set_current_win(parent.winnr)
  vim.api.nvim_set_current_buf(parent.bufnr)

  vim.api.nvim_buf_call(parent.bufnr, function()
    buffer:on({ event.BufLeave, event.BufWinLeave }, function ()
      vim.schedule(function()
        buffer:hide()
        -- buffer:unmount()
      end)
    end, { once = true })
  end)

  buffer:show()
end

return M

