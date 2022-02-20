local utils   = require'nvim-regexplainer.util.utils'
local autocmd = require'nui.utils.autocmd'
local event   = autocmd.event

-- Functions to create or modify the buffer which displays the regexplanation
--
local M = {}

-- Get the buffer in which to render the explainer
--
function M.get_buffer(options, parent_bufnr)
  if options.display == 'split' then
    return require'nui.split' {
      relative = 'editor',
      position = 'bottom',
      enter = false,
      focusable = false,
      size = '20%',
      buf_options = {
        readonly = true,
        modifiable = false,
      },
      win_options = {
        wrap = true,
        conceallevel = 2,
      },
    }
  elseif options.display == 'popup' then
    local buffer = require'nui.popup' {
      position = 1,
      relative = 'cursor',
      enter = false,
      focusable = false,
      size = {
        width = '75%',
        height = 5,
      },
      border = {
        padding = { 1, 2 },
        style = 'shadow',
      },
      buf_options = {
        readonly = false,
        modifiable = true,
      },
      win_options = {
        wrap = true,
        conceallevel = 3,
      },
    }

    autocmd.buf.define(parent_bufnr, event.CursorMoved, function()
      buffer:unmount()
    end, { once = true })

    return buffer
  end
end

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

function M.finalize(buffer, parent_bufnr)
  if is_popup(buffer) then
    buffer:set_size {
      width = '75%',
      height = vim.api.nvim_buf_line_count(buffer.bufnr),
    }
  end

  vim.api.nvim_buf_call(parent_bufnr, function()
   vim.api.nvim_set_current_buf(parent_bufnr)
    buffer:on({ event.BufLeave, event.BufWinLeave }, function ()
      vim.schedule(function()
        buffer:unmount()
      end)
    end, { once = true })
  end)
end

return M

