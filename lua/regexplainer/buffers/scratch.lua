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

---Yank the contents of the buffer, optionally into a specified register
---@param register? string The register to yank to. defaults to '*'
function Scratch:yank(register)
  register = register or '*'
  vim.api.nvim_buf_call(self.bufnr, function()
    vim.cmd('%y' .. register)
  end)
end

return Scratch
