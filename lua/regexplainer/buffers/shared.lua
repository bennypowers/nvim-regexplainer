local M = {}

---@class RegexplainerWindowOptions
---@field wrap?         boolean
---@field conceallevel? 0|1|2|3

---@class RegexplainerBufOptions
---@field filetype?     string
---@field readonly?     boolean
---@field modifiable?   boolean
---@field buflisted?    boolean

---@class RegexplainerBorderOptions
---@field style?   string  # border style for nvim_open_win ('shadow', 'rounded', etc.)
---@field padding? number[] # vertical, horizontal padding

---@class RegexplainerBufferOptions
---@field enter?       boolean
---@field focusable?   boolean
---@field buf_options? RegexplainerBufOptions
---@field win_options? RegexplainerWindowOptions

---@class RegexplainerPopupOptions: RegexplainerBufferOptions
---@field relative? string  # 'cursor'|'editor'|'win'
---@field position? number  # row offset from anchor
---@field size?     number
---@field border?   RegexplainerBorderOptions

---@class RegexplainerSplitOptions: RegexplainerBufferOptions
---@field relative? string  # 'editor'|'window'
---@field position? string  # 'bottom'|'top'
---@field size?     string|number # '20%' or absolute lines

---@class RegexplainerBuffer
---@field type       "Popup"|"Split"|"Scratch"
---@field bufnr      number
---@field winid      number|nil
---@field _          { mounted: boolean }
---@field init       fun(self:RegexplainerBuffer,lines:string[],options:RegexplainerOptions,state:RegexplainerRendererState)
---@field after      fun(self:RegexplainerBuffer,lines:string[],options:RegexplainerOptions,state:RegexplainerRendererState)
---@field mount      fun(self:RegexplainerBuffer)
---@field unmount    fun(self:RegexplainerBuffer)
---@field hide       fun(self:RegexplainerBuffer)
---@field set_size?  fun(self:RegexplainerBuffer,config:{width:number|string,height:number})
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
  if options.auto then
    vim.api.nvim_create_autocmd({ 'BufHidden', 'BufLeave' }, {
      group = vim.api.nvim_create_augroup('regexplainer_buf_after', { clear = true }),
      buffer = state.last.parent.bufnr,
      callback = function()
        M.kill_buffer(self)
      end
    })
  end
end

function M.default_buffer_init(self, _, _, _)
  if not self._.mounted then self:mount() end
end

return M
