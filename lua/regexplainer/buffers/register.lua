local Shared = require'regexplainer.buffers.shared'
local Buffers = require'regexplainer.buffers'

local M = {}

---A Nui-compatible scratch buffer.
---ephemeral, invisible, unlisted
---
---@class ScratchBuffer
---@field _ NuiBufferOptions
---@field bufnr number
local Scratch = setmetatable({
  super = nil
}, {
  __name = 'Scratch',
  __call = function(class, options)
    local self = setmetatable({}, { __index = class })
    self._ = {
      buf_options = options.buf_options,
      loading = false,
      mounted = false,
      win_enter = options.enter,
      win_options = options.win_options,
    }
    self.bufnr = vim.api.nvim_create_buf(false, true)
    self.type = 'Scratch'
    return self
  end
})

---Adhere to the NUI buffer interface by setting the `mounted` flag
function Scratch:mount()
  self._.mounted = true;
end

---Delete the buffer and unset the `mounted` flag
function Scratch:unmount()
  vim.api.nvim_buf_delete(self.bufnr, { force = true })
  self._.mounted = false;
end

local function get_buffer_contents(bufnr)
  local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(content, '\n')
end

---Yank the contents of the buffer, optionally into a specified register
---@param bufnr number The buffer to yank
---@param register? string The register to yank to. defaults to '*'
local function yank(bufnr, register)
  register = register or '*'
  vim.api.nvim_buf_call(bufnr, function()
    vim.fn.setreg(register, get_buffer_contents(bufnr), 'l')
  end)
end

local function after(self, _, options, _)
  yank(self.bufnr, options.register or '"')
  Buffers.kill_buffer(self)
end

--- Create scratch buffer
function M.get_buffer(_, _)
  local buffer = Scratch({})
  buffer.type = 'Scratch'
  buffer.init = Shared.default_buffer_init
  buffer.after = after
  return buffer
end

return M

