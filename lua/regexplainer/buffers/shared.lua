local M = {}

---@class RegexplainerBuffer: ScratchBuffer|NuiPopup|NuiSplit
---@field type       "NuiPopup"|"NuiSplit"|"Scratch"
---@field init       function(buf: RegexplainerBuffer, lines: string[], options: RegexplainerOptions, components: RegexplainerComponent[], state: RegexplainerRendererState): nil
---@field after      function(buf: RegexplainerBuffer, lines: string[], options: RegexplainerOptions, components: RegexplainerComponent[], state: RegexplainerRendererState): nil

---@class WindowOptions
---@field wrap         boolean
---@field conceallevel 0|1|2|3

---@class BufferOptions
---@field filetype     string
---@field readonly     boolean
---@field modifiable   boolean

---@class NuiSplitBufferOptions: NuiBufferOptions
---@field relative "'editor'"|"'window'"
---@field position "'bottom'"|"'top'"
---@field size     string

---@class NuiBorderOptions
---@field padding number[]
---@field style   "'shadow'"|"'double'"

---@class NuiPopupBufferOptions: NuiBufferOptions
---@field relative "'cursor'"
---@field position number
---@field size     number|table<"'width'"|"'height'", number>
---@field border   NuiBorderOptions

---@alias RegexplainerBufferOptions NuiSplitBufferOptions|NuiPopupBufferOptions

---@class NuiBufferOptions
---@field enter       boolean
---@field focusable   boolean
---@field buf_options BufferOptions
---@field win_options WindowOptions
--
M.shared_options = {
  enter = false,
  focusable = false,
  buf_options = {
    filetype = 'Regexplainer',
    readonly = false,
    modifiable = true,
  },
  win_options = {
    wrap = true,
    conceallevel = 2,
  },
}

function M.default_buffer_after(self, _, options, _, state)
  local autocmd = require 'nui.utils.autocmd'
  local event   = autocmd.event

  if options.auto then
    autocmd.buf.define(state.last.parent.bufnr, {
      event.BufHidden,
      event.BufLeave,
    }, function()
      M.kill_buffer(self)
    end)
  end
end

function M.default_buffer_init(self, _, _, _)
  if not self._.mounted then self:mount() end
end

return M
