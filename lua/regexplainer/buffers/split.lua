local Shared = require 'regexplainer.buffers.shared'

local set_current_win = vim.api.nvim_set_current_win
local set_current_buf = vim.api.nvim_set_current_buf
local win_set_height = vim.api.nvim_win_set_height
local extend = vim.tbl_deep_extend

local M = {}

local split_defaults = {
  relative = 'editor',
  position = 'bottom',
  size = '20%',
  enter = false,
  focusable = false,
  buf_options = {
    filetype = 'Regexplainer',
    readonly = true,
    modifiable = false,
    buflisted = false,
  },
}

--- Native split window replacing nui.split
local SplitWin = {}
SplitWin.__index = SplitWin

function SplitWin.new(opts)
  local self = setmetatable({}, SplitWin)
  self.type = 'Split'
  self._opts = opts
  self._ = { mounted = false }
  self.bufnr = vim.api.nvim_create_buf(false, true)

  -- Apply buf_options except readonly/modifiable, which are deferred
  -- until after content is written (see after callback)
  if opts.buf_options then
    for k, v in pairs(opts.buf_options) do
      if k ~= 'readonly' and k ~= 'modifiable' then
        pcall(function() vim.bo[self.bufnr][k] = v end)
      end
    end
  end

  return self
end

function SplitWin:mount()
  if self._.mounted then return end

  local cur_win = vim.api.nvim_get_current_win()

  vim.cmd('botright new')
  self.winid = vim.api.nvim_get_current_win()
  local tmp_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(self.winid, self.bufnr)
  pcall(vim.api.nvim_buf_delete, tmp_buf, { force = true })

  local size = self._opts.size or '20%'
  if type(size) == 'string' then
    local pct = tonumber(size:match('(%d+)%%'))
    if pct then
      win_set_height(self.winid, math.floor(vim.o.lines * pct / 100))
    end
  elseif type(size) == 'number' then
    win_set_height(self.winid, size)
  end

  if self._opts.win_options then
    for k, v in pairs(self._opts.win_options) do
      pcall(function() vim.wo[self.winid][k] = v end)
    end
  end

  if not self._opts.enter then
    set_current_win(cur_win)
  end

  self._.mounted = true
end

function SplitWin:unmount()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
  self.winid = nil
  self._.mounted = false
end

function SplitWin:hide()
  if _G._regexplainer_hologram_image and _G._regexplainer_hologram_bufnr then
    pcall(function()
      _G._regexplainer_hologram_image:delete(_G._regexplainer_hologram_bufnr, { free = true })
      _G._regexplainer_hologram_image = nil
      _G._regexplainer_hologram_bufnr = nil
    end)
  end

  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  self.winid = nil
end

local function after(self, lines, options, state)
  -- Lock down buffer now that content has been written
  local buf_opts = self._opts.buf_options or {}
  if buf_opts.readonly then vim.bo[self.bufnr].readonly = true end
  if buf_opts.modifiable == false then vim.bo[self.bufnr].modifiable = false end

  -- Set flag to prevent cursor exit detection until setup is complete
  self._setup_complete = false
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
    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(string.format('Split height set to %d', split_height), 'info')
    end
  else
    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(string.format('Invalid winid %s, cannot set height', self.winid or 'nil'), 'warn')
    end
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
        vim.bo[self.bufnr].modifiable = true
        vim.bo[self.bufnr].readonly = false
        vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {''})
        vim.bo[self.bufnr].readonly = true
        vim.bo[self.bufnr].modifiable = false
        
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
    vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
      callback = function()
        -- Only trigger if setup is complete
        if not self._setup_complete then
          return
        end
        
        -- Use the same logic as auto mode - check if there's still a regexp at cursor
        local tree = require 'regexplainer.utils.treesitter'
        if not tree.has_regexp_at_cursor() then
          -- No longer on a regex pattern, hide the split
          if self and self.hide then
            self:hide()
          end
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
end

function M.get_buffer(options, state)
  if state.last.type == 'Split' then
    if state.last.winid and vim.api.nvim_win_is_valid(state.last.winid) then
      return state.last
    else
      state.last = { type = nil }
    end
  end

  local buffer = SplitWin.new(extend('force', Shared.shared_options, split_defaults, options.split or {}))
  buffer.type = 'Split'
  state.last = buffer
  buffer.init = function(self, lines, options, state)
    Shared.default_buffer_init(self, lines, options, state)
    if options.debug then
      local utils = require 'regexplainer.utils'
      utils.notify(string.format('Split mounted, winid: %s', self.winid), 'info')
    end
  end
  buffer.after = after

  return buffer
end

return M
