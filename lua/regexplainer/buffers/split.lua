local Shared = require 'regexplainer.buffers.shared'
local Split = require 'nui.split'

local set_current_win = vim.api.nvim_set_current_win
local set_current_buf = vim.api.nvim_set_current_buf
local win_set_height = vim.api.nvim_win_set_height
local extend = vim.tbl_deep_extend

local M = {}

---@type NuiSplitBufferOptions
local split_defaults = {
  relative = 'editor',
  position = 'bottom',
  size = '20%',
  enter = false,  -- Don't enter the split window
  focusable = false,  -- Don't allow focus
  buf_options = {
    filetype = 'Regexplainer',
    readonly = true,
    modifiable = false,
    buflisted = false,
  },
}

local function after(self, lines, options, state)
  -- Set flag to prevent cursor exit detection until setup is complete
  self._setup_complete = false
  local utils = require 'regexplainer.utils'
  utils.notify('Split after() starting', 'info')
  set_current_win(state.last.parent.winnr)
  set_current_buf(state.last.parent.bufnr)
  
  -- Calculate proper height based on content type
  local split_height
  if state and state.image_data then
    -- For image mode, calculate height based on image dimensions
    local opts = state.graphical_opts or {}
    local char_height = opts.char_height or math.ceil((opts.height or 20) / 20) -- Convert pixels to approximate character height
    split_height = char_height + 2 -- Add some padding
    
    -- Debug output removed for cleaner operation
  else
    -- For text mode, use line count
    split_height = #lines
  end
  
  -- Check if winid is valid before setting height
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    win_set_height(self.winid, split_height)
    utils.notify(string.format('Split height set to %d', split_height), 'info')
  else
    utils.notify(string.format('Invalid winid %s, cannot set height', self.winid or 'nil'), 'warn')
  end
  
  -- Display image in split mode if we have image data
  if state and state.image_data then
    local graphics = require 'regexplainer.graphics'
    
    -- Add a small delay to ensure the split window is fully set up
    vim.defer_fn(function()
      local opts = state.graphical_opts or {}
      
      -- Switch to the split window before displaying the image
      local split_win = nil
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == self.bufnr then
          split_win = win
          break
        end
      end
      
      if split_win and vim.api.nvim_win_is_valid(split_win) then
        local original_win = vim.api.nvim_get_current_win()
        
        -- Temporarily make buffer modifiable to set content
        vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', true)
        vim.api.nvim_buf_set_option(self.bufnr, 'readonly', false)
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {''})
        vim.api.nvim_buf_set_option(self.bufnr, 'readonly', true)
        vim.api.nvim_buf_set_option(self.bufnr, 'modifiable', false)
        
        -- Only switch to split window if it's still valid
        if vim.api.nvim_win_is_valid(split_win) then
          vim.api.nvim_set_current_win(split_win)
          
          -- Check if window is still valid before setting cursor
          if vim.api.nvim_win_is_valid(split_win) then
            vim.api.nvim_win_set_cursor(split_win, {1, 0})
          end
          
          -- Display image in split buffer while split window is current
          local success = graphics.display_image(state.image_data, {
            width = opts.width,
            height = opts.height,
            buffer = self.bufnr,
          })
          
          -- Switch back to original window if it's still valid
          if vim.api.nvim_win_is_valid(original_win) then
            vim.api.nvim_set_current_win(original_win)
          end
        end
      end
    end, 150)
  end
  
  -- Add cursor exit handling to hide split (like popup mode)
  if options.auto then
    utils.notify('Setting up cursor exit autocmd', 'info')
    vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
      callback = function()
        -- Only trigger if setup is complete
        if not self._setup_complete then
          utils.notify('Cursor moved but setup not complete, ignoring', 'info')
          return
        end
        
        utils.notify('Cursor moved and setup complete, checking regexp', 'info')
        
        -- Use the same logic as auto mode - check if there's still a regexp at cursor
        local tree = require 'regexplainer.utils.treesitter'
        if not tree.has_regexp_at_cursor() then
          utils.notify('No regexp at cursor, hiding split', 'info')
          -- No longer on a regex pattern, hide the split
          if self and self.hide then
            self:hide()
          end
        else
          utils.notify('Still on regexp, keeping split', 'info')
        end
      end,
      once = true,
    })
    
    -- Add cleanup autocmd like other buffer types, but only for the parent buffer being closed/hidden
    -- NOT for temporary window switches
    vim.api.nvim_create_autocmd({ 'BufWinLeave' }, {
      group = vim.api.nvim_create_augroup('regexplainer_split_cleanup', { clear = true }),
      buffer = state.last.parent.bufnr,
      callback = function()
        -- Only cleanup if the parent buffer is actually being closed, not just losing focus
        if not vim.api.nvim_buf_is_loaded(state.last.parent.bufnr) then
          local Buffers = require 'regexplainer.buffers'
          Buffers.kill_buffer(self)
        end
      end
    })
  end
  
  -- Mark setup as complete at the very end
  self._setup_complete = true
  utils.notify('Split after() complete', 'info')
end

function M.get_buffer(options, state)
  local utils = require 'regexplainer.utils'
  
  if state.last.type == 'NuiSplit' then
    utils.notify('Reusing existing split buffer', 'info')
    -- Check if the split still exists and is valid
    if state.last.winid and vim.api.nvim_win_is_valid(state.last.winid) then
      utils.notify('Split window still valid, reusing', 'info')
      return state.last
    else
      utils.notify('Split window invalid, creating new one', 'info')
      -- Reset the state so we create a new split
      state.last = { type = nil }
    end
  end
  
  utils.notify('Creating new split buffer', 'info')
  local buffer = Split(extend('force', Shared.shared_options, split_defaults, options.split or {}))
  buffer.type = 'NuiSplit'
  state.last = buffer
  buffer.init = function(self, lines, options, state)
    utils.notify('Split init() called', 'info')
    Shared.default_buffer_init(self, lines, options, state)
    utils.notify(string.format('Split mounted, winid: %s', self.winid), 'info')
  end
  buffer.after = after
  
  -- Override hide method to add debugging and cleanup hologram
  local original_hide = buffer.hide
  buffer.hide = function(self)
    utils.notify('Split hide() called!', 'warn')
    utils.notify(debug.traceback('Hide called from:', 2), 'warn')
    
    -- Clean up any hologram images when hiding
    if _G._regexplainer_hologram_image and _G._regexplainer_hologram_bufnr then
      pcall(function()
        _G._regexplainer_hologram_image:delete(_G._regexplainer_hologram_bufnr, { free = true })
        _G._regexplainer_hologram_image = nil
        _G._regexplainer_hologram_bufnr = nil
      end)
    end
    
    if original_hide then
      original_hide(self)
    end
  end
  
  return buffer
end

return M
