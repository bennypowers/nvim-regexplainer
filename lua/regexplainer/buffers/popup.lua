local Shared = require 'regexplainer.buffers.shared'

local M = {}

local au = vim.api.nvim_create_autocmd
local get_win_width = vim.api.nvim_win_get_width
local extend = vim.tbl_deep_extend

--- Clean up hologram image if it exists
local function cleanup_hologram_image()
  if _G._regexplainer_hologram_image and _G._regexplainer_hologram_bufnr then
    pcall(function()
      _G._regexplainer_hologram_image:delete(_G._regexplainer_hologram_bufnr, {free = true})
    end)
    _G._regexplainer_hologram_image = nil
    _G._regexplainer_hologram_bufnr = nil
  end
end

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
  local height = #lines

  -- Check if we have image dimensions (for graphical mode)
  if state.image_char_width and state.image_char_height then
    -- Use image dimensions for popup sizing
    width = state.image_char_width
    height = state.image_char_height
    
    -- Ensure minimum size and respect window limits
    width = math.max(30, math.min(width, math.floor(win_width * 0.9)))
    height = math.max(5, math.min(height, 40))
  else
    -- Traditional text-based sizing
    for _, line in ipairs(lines) do
      if #line > width then
        width = #line
      end
    end

    if (win_width * .75) < width then
      width = '75%'
    end
  end

  self:set_size { width = width, height = height }
end

local function after(self, _, options, state)
  if options.auto then
    -- For graphical mode with image data, use smart cursor tracking
    if state.image_data and state.full_regexp_range then
      local augroup = vim.api.nvim_create_augroup('RegexplainerGraphicalPopup', { clear = false })
      
      au('CursorMoved', {
        buffer = state.last.parent.bufnr,
        group = augroup,
        callback = function() 
          local cursor_pos = vim.api.nvim_win_get_cursor(0)
          local cursor_line = cursor_pos[1]
          local cursor_col = cursor_pos[2]
          
          -- Check if cursor is within the regex pattern range
          local range = state.full_regexp_range
          if range then
            if cursor_line == range.start.row + 1 then
              if cursor_col >= range.start.column and cursor_col <= range.finish.column then
                -- Cursor is still within regex pattern, don't close
                return
              end
            end
          end
          
          -- Cursor moved out of regex pattern, close popup
          vim.api.nvim_del_augroup_by_id(augroup)
          cleanup_hologram_image()
          self:unmount() 
        end,
      })
      
      -- Also close on buffer leave
      au({ 'BufLeave', 'BufWinLeave' }, {
        buffer = state.last.parent.bufnr,
        group = augroup,
        once = true,
        callback = function() 
          vim.api.nvim_del_augroup_by_id(augroup)
          cleanup_hologram_image()
          self:unmount() 
        end,
      })
    else
      -- Traditional behavior for text mode
      au({ 'BufLeave', 'BufWinLeave', 'CursorMoved' }, {
        buffer = state.last.parent.bufnr,
        once = true,
        callback = function() 
          cleanup_hologram_image()
          self:unmount() 
        end,
      })
    end
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
