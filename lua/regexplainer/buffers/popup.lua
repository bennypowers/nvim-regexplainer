local Shared = require 'regexplainer.buffers.shared'

local M = {}

local au = vim.api.nvim_create_autocmd
local get_win_width = vim.api.nvim_win_get_width
local extend = vim.tbl_deep_extend

--- Clean up hologram image if it exists
local function cleanup_hologram_image()
  if _G._regexplainer_hologram_image and _G._regexplainer_hologram_bufnr then
    pcall(function()
      _G._regexplainer_hologram_image:delete(_G._regexplainer_hologram_bufnr, { free = true })
    end)
    _G._regexplainer_hologram_image = nil
    _G._regexplainer_hologram_bufnr = nil
  end
end

local popup_defaults = {
  position = 1,
  relative = 'cursor',
  size = 1,
  border = {
    style = 'shadow',
    padding = { 1, 2 },
  },
}

--- Native popup window replacing nui.popup
---@class RegexplainerPopup: RegexplainerBuffer
---@field _opts    RegexplainerPopupOptions
---@field _width   number
---@field _height  number
---@field _pad_top    number
---@field _pad_right  number
---@field _pad_bottom number
---@field _pad_left   number
local Popup = {}
Popup.__index = Popup

function Popup.new(opts)
  local self = setmetatable({}, Popup)
  self.type = 'Popup'
  self._opts = opts
  self._width = 1
  self._height = 1

  local padding = opts.border and opts.border.padding or {}
  self._pad_top = padding[1] or 0
  self._pad_right = padding[2] or 0
  self._pad_bottom = padding[3] or padding[1] or 0
  self._pad_left = padding[4] or padding[2] or 0

  self._ = { mounted = false }
  self.bufnr = vim.api.nvim_create_buf(false, true)

  if opts.buf_options then
    for k, v in pairs(opts.buf_options) do
      pcall(function() vim.bo[self.bufnr][k] = v end)
    end
  end

  return self
end

function Popup:mount()
  if self._.mounted then return end

  self.winid = vim.api.nvim_open_win(self.bufnr, self._opts.enter or false, {
    relative = self._opts.relative or 'cursor',
    row = self._opts.position or 1,
    col = 0,
    width = math.max(1, self._width),
    height = math.max(1, self._height),
    style = 'minimal',
    border = self._opts.border and self._opts.border.style or 'none',
    focusable = self._opts.focusable or false,
    zindex = 50,
  })

  if self._opts.win_options then
    for k, v in pairs(self._opts.win_options) do
      pcall(function() vim.wo[self.winid][k] = v end)
    end
  end

  if self._pad_left > 0 then
    vim.wo[self.winid].foldcolumn = tostring(self._pad_left)
    local whl = vim.wo[self.winid].winhighlight
    local fc = 'FoldColumn:NormalFloat'
    vim.wo[self.winid].winhighlight = (whl ~= '' and whl .. ',' or '') .. fc
  end

  self._.mounted = true
end

function Popup:unmount()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
  self.winid = nil
  self._.mounted = false
end

function Popup:hide()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  self.winid = nil
  self._.mounted = false
end

function Popup:set_size(config)
  local width = config.width
  local height = config.height

  if type(width) == 'string' then
    local pct = tonumber(width:match('(%d+)%%'))
    if pct then
      width = math.floor(get_win_width(0) * pct / 100)
    else
      width = 40
    end
  end

  width = math.max(1, (width or 1) + self._pad_left + self._pad_right)
  height = math.max(1, (height or 1) + self._pad_top + self._pad_bottom)
  self._width = width
  self._height = height

  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_set_config(self.winid, {
      relative = self._opts.relative or 'cursor',
      row = self._opts.position or 1,
      col = 0,
      width = width,
      height = height,
    })
  end
end

function Popup:apply_padding()
  -- Top/bottom padding is handled by the window being taller than the content.
  -- Left padding is handled via foldcolumn (set in mount).
  -- No buffer content modification needed.
end

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

    if (win_width * 0.75) < width then
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
  vim.api.nvim_buf_set_lines(pattern_bufnr, 0, -1, false, { formatted_pattern })

  -- Set filetype to javascript for syntax highlighting
  vim.bo[pattern_bufnr].filetype = 'javascript'

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
      string.format(
        'Image window position: row=%.1f, col=%.1f, relative=%s, pattern will be at row=%.1f',
        image_config.row,
        image_config.col,
        image_config.relative or 'editor',
        image_config.row - 1
      ),
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
        string.format(
          'Cursor window row: line %d - topline %d = row %d',
          cursor_row_abs,
          win_info.topline,
          cursor_win_row
        ),
        'info'
      )
    end

    -- Handle positioning based on whether image popup covers cursor
    local image_bottom_row = image_config.row + (image_height or 1)

    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(
        string.format(
          'Image spans rows %.1f to %.1f, cursor at window row %d',
          image_config.row,
          image_bottom_row,
          cursor_win_row
        ),
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
          utils.notify(string.format('Pattern row would be invisible, using cursor row %d', cursor_win_row), 'info')
        end
      end
    end
  end

  if options.debug then
    local utils = require 'regexplainer.utils'
    utils.notify(
      string.format(
        'Pattern popup positioning: image at row=%.1f, pattern at row=%.1f, relative=%s',
        image_config.row,
        pattern_row,
        image_config.relative or 'editor'
      ),
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
  elseif signcolumn:match '^yes:(%d+)$' then
    local width = tonumber(signcolumn:match '^yes:(%d+)$')
    gutter_width = gutter_width + width
  elseif signcolumn:match '^auto:(%d+)$' then
    local width = tonumber(signcolumn:match '^auto:(%d+)$')
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
      string.format(
        'Gutter width: %d, image col: %.1f + padding: %d + gutter: %d = pattern col: %.1f',
        gutter_width,
        image_config.col,
        image_left_padding,
        gutter_width,
        pattern_col
      ),
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
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    callback = function()
      if _G._regexplainer_pattern_popup then
        pcall(vim.api.nvim_win_close, _G._regexplainer_pattern_popup.winid, true)
        pcall(vim.api.nvim_buf_delete, _G._regexplainer_pattern_popup.bufnr, { force = true })
        _G._regexplainer_pattern_popup = nil
      end
    end,
    once = true,
  })
end

local function after(self, _, options, state)
  self:apply_padding()

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
      utils.notify(
        string.format(
          'Pattern popup check: winid=%s, valid=%s',
          tostring(image_winid),
          image_winid and vim.api.nvim_win_is_valid(image_winid) and 'true' or 'false'
        ),
        'info'
      )
    end

    if image_winid and vim.api.nvim_win_is_valid(image_winid) then
      local image_config = vim.api.nvim_win_get_config(image_winid)

      if options.debug then
        utils.notify(
          string.format(
            'Raw config: row=%.1f, col=%.1f, relative=%s',
            image_config.row,
            image_config.col,
            image_config.relative or 'editor'
          ),
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
            string.format(
              'Win-relative calc: topline=%d + row=%.1f = %d',
              win_top_line,
              image_config.row,
              popup_first_row
            ),
            'info'
          )
        end
      else
        popup_first_row = image_config.row + 1 -- Default assumption
      end

      if options.debug then
        utils.notify(
          string.format(
            'Cursor at line %d, popup starts at line %d (relative=%s)',
            cursor_row,
            popup_first_row,
            image_config.relative or 'editor'
          ),
          'info'
        )
      end

      -- Only show pattern popup if popup covers or is above the cursor line
      if popup_first_row <= cursor_row then
        if options.debug then
          utils.notify('Popup covers cursor - showing pattern popup', 'info')
        end
        -- this is annoying and kind of broken, so I'm removing it for now
        -- but will keep the code, in case I decide to reimplement
        -- create_pattern_popup(state.full_regexp_text, self, options, state.image_char_height)
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
  local buffer = Popup.new(extend('force', Shared.shared_options, popup_defaults, options.popup or {}))
  buffer.type = 'Popup'
  state.last = buffer
  buffer.init = init
  buffer.after = after
  return buffer
end

return M
