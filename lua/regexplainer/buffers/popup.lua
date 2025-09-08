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

--- Create a small popup above image popup showing the regex pattern
---@param pattern_text string # The regex pattern to display
---@param image_buffer RegexplainerBuffer # The image popup buffer for positioning
---@param options RegexplainerOptions # Renderer options
---@param image_height number # Height of the image popup in characters
local function create_pattern_popup(pattern_text, image_buffer, options, image_height)
  -- Format pattern with JavaScript regex delimiters
  local formatted_pattern = '/' .. pattern_text .. '/'
  
  -- Create a small buffer for the pattern text
  local pattern_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(pattern_bufnr, 0, -1, false, {formatted_pattern})
  
  -- Set filetype to javascript for syntax highlighting
  vim.api.nvim_buf_set_option(pattern_bufnr, 'filetype', 'javascript')
  
  -- Get the NUI popup's actual screen position using window config
  local pattern_width = #formatted_pattern
  
  local image_winid = image_buffer.winid
  if not image_winid or not vim.api.nvim_win_is_valid(image_winid) then
    -- Fallback to cursor position if window not available
    local win_config = {
      relative = 'cursor',
      row = 0,
      col = 0,
      width = pattern_width,
      height = 1,
      style = 'minimal',
      border = 'none',
      focusable = false,
      zindex = 60,
    }
    local pattern_winid = vim.api.nvim_open_win(pattern_bufnr, false, win_config)
    _G._regexplainer_pattern_popup = { bufnr = pattern_bufnr, winid = pattern_winid }
    return
  end
  
  -- Get the actual window configuration
  local image_config = vim.api.nvim_win_get_config(image_winid)
  
  if options.debug then
    local utils = require 'regexplainer.utils'
    utils.notify(
      string.format('Image window position: row=%.1f, col=%.1f, relative=%s, pattern will be at row=%.1f', 
        image_config.row, image_config.col, image_config.relative or 'editor', image_config.row - 1),
      'info'
    )
  end
  
  -- Position one row above the image popup, but handle edge cases
  local pattern_row = image_config.row - 1 -- One row above image popup
  
  -- For win-relative positioning, calculate cursor's window row for comparison
  if image_config.relative == 'win' then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_row_abs = cursor_pos[1] 
    local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    local cursor_win_row = cursor_row_abs - win_info.topline -- Cursor's row relative to window
    
    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(
        string.format('Cursor window row: line %d - topline %d = row %d', 
          cursor_row_abs, win_info.topline, cursor_win_row),
        'info'
      )
    end
    
    -- Handle positioning based on whether image popup covers cursor
    local image_bottom_row = image_config.row + (image_height or 1)
    
    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(
        string.format('Image spans rows %.1f to %.1f, cursor at window row %d', 
          image_config.row, image_bottom_row, cursor_win_row),
        'info'
      )
    end
    
    if pattern_row <= 0 then
      -- Pattern would be invisible above window
      if cursor_win_row >= image_config.row and cursor_win_row <= image_bottom_row then
        -- Cursor is covered by image popup - place pattern popup above image
        pattern_row = math.max(1, image_config.row - 1)
        if options.debug then
          local utils = require 'regexplainer.utils'
          utils.notify(
            string.format('Cursor covered by image, placing pattern above image at row %.1f', pattern_row),
            'info'
          )
        end
      else
        -- Cursor not covered - place at cursor
        pattern_row = cursor_win_row
        if options.debug then
          local utils = require 'regexplainer.utils'
          utils.notify(
            string.format('Pattern row would be invisible, using cursor row %d', cursor_win_row),
            'info'
          )
        end
      end
    end
  end
  
  if options.debug then
    local utils = require 'regexplainer.utils'
    utils.notify(
      string.format('Pattern popup positioning: image at row=%.1f, pattern at row=%.1f, relative=%s', 
        image_config.row, pattern_row, image_config.relative or 'editor'),
      'info'
    )
  end
  
  -- Calculate actual gutter width (numbercolumn, signcolumn, foldcolumn)
  local win = vim.api.nvim_get_current_win()
  local gutter_width = 0
  
  -- Get number column width
  local number = vim.wo[win].number or vim.wo[win].relativenumber
  if number then
    gutter_width = gutter_width + vim.wo[win].numberwidth
  end
  
  -- Get sign column width  
  local signcolumn = vim.wo[win].signcolumn
  if signcolumn == 'yes' then
    gutter_width = gutter_width + 2
  elseif signcolumn == 'auto' then
    -- Check if there are any signs
    local signs = vim.fn.sign_getplaced(vim.api.nvim_get_current_buf())
    if #signs > 0 and #signs[1].signs > 0 then
      gutter_width = gutter_width + 2
    end
  elseif signcolumn:match('^yes:(%d+)$') then
    local width = tonumber(signcolumn:match('^yes:(%d+)$'))
    gutter_width = gutter_width + width
  elseif signcolumn:match('^auto:(%d+)$') then
    local width = tonumber(signcolumn:match('^auto:(%d+)$'))
    local signs = vim.fn.sign_getplaced(vim.api.nvim_get_current_buf())
    if #signs > 0 and #signs[1].signs > 0 then
      gutter_width = gutter_width + width
    end
  end
  
  -- Get fold column width
  gutter_width = gutter_width + vim.wo[win].foldcolumn
  
  -- Account for image popup padding and add gutter offset
  local image_left_padding = 2 -- Image popup padding
  local pattern_col = image_config.col + image_left_padding + gutter_width
  
  if options.debug then
    local utils = require 'regexplainer.utils'
    utils.notify(
      string.format('Gutter width: %d, image col: %.1f + padding: %d + gutter: %d = pattern col: %.1f', 
        gutter_width, image_config.col, image_left_padding, gutter_width, pattern_col),
      'info'
    )
  end
  
  local win_config = {
    relative = image_config.relative or 'editor',
    row = pattern_row,
    col = pattern_col,
    width = pattern_width,
    height = 1,
    style = 'minimal',
    border = 'none',
    focusable = false,
    zindex = (image_config.zindex or 50) + 1, -- Above image popup
  }
  
  -- Create the popup window
  local pattern_winid = vim.api.nvim_open_win(pattern_bufnr, false, win_config)
  
  -- Store reference for cleanup
  _G._regexplainer_pattern_popup = {
    bufnr = pattern_bufnr,
    winid = pattern_winid,
  }
  
  -- Auto-close popup when cursor moves
  vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
    callback = function()
      if _G._regexplainer_pattern_popup then
        pcall(vim.api.nvim_win_close, _G._regexplainer_pattern_popup.winid, true)
        pcall(vim.api.nvim_buf_delete, _G._regexplainer_pattern_popup.bufnr, {force = true})
        _G._regexplainer_pattern_popup = nil
      end
    end,
    once = true,
  })
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
  
  -- Create pattern popup for graphical mode (only when popup covers cursor)
  if state.image_data and state.full_regexp_text then
    local utils = require 'regexplainer.utils'
    
    -- Get cursor position and popup position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_row = cursor_pos[1] -- 1-indexed
    
    local image_winid = self.winid
    if options.debug then
      utils.notify(string.format('Pattern popup check: winid=%s, valid=%s', 
        tostring(image_winid), 
        image_winid and vim.api.nvim_win_is_valid(image_winid) and 'true' or 'false'), 'info')
    end
    
    if image_winid and vim.api.nvim_win_is_valid(image_winid) then
      local image_config = vim.api.nvim_win_get_config(image_winid)
      
      if options.debug then
        utils.notify(
          string.format('Raw config: row=%.1f, col=%.1f, relative=%s', 
            image_config.row, image_config.col, image_config.relative or 'editor'),
          'info'
        )
      end
      
      -- Handle different relative positioning
      local popup_first_row
      if image_config.relative == 'cursor' then
        popup_first_row = cursor_row + image_config.row
      elseif image_config.relative == 'editor' then
        popup_first_row = image_config.row + 1 -- Convert 0-indexed to 1-indexed
      elseif image_config.relative == 'win' then
        -- For win-relative, get the window's top line and add the popup's row offset
        local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
        local win_top_line = win_info.topline -- First visible line in window
        popup_first_row = win_top_line + image_config.row
        
        if options.debug then
          utils.notify(
            string.format('Win-relative calc: topline=%d + row=%.1f = %d', 
              win_top_line, image_config.row, popup_first_row),
            'info'
          )
        end
      else
        popup_first_row = image_config.row + 1 -- Default assumption
      end
      
      if options.debug then
        utils.notify(
          string.format('Cursor at line %d, popup starts at line %d (relative=%s)', 
            cursor_row, popup_first_row, image_config.relative or 'editor'),
          'info'
        )
      end
      
      -- Only show pattern popup if popup covers or is above the cursor line
      if popup_first_row <= cursor_row then
        if options.debug then
          utils.notify('Popup covers cursor - showing pattern popup', 'info')
        end
        create_pattern_popup(state.full_regexp_text, self, options, state.image_char_height)
      else
        if options.debug then
          utils.notify('Popup below cursor - pattern still visible, no need for pattern popup', 'info')
        end
      end
    else
      if options.debug then
        utils.notify('Invalid window ID - cannot determine popup position', 'warning')
      end
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
