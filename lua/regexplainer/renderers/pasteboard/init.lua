--- A debug renderer that yanks the narrative output to the os pasteboard
---@type RegexplainerRenderer
--
local M = {}

---@param buffer NuiBuffer
---@param lines  string[]
function M.set_lines(buffer, lines)
    -- Create scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_call(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, 0, #lines, false, lines)
        vim.cmd[[%y*]]
    end)

    -- Cleanup scratch buffer
    vim.api.nvim_buf_delete(bufnr, { force = true })
end

---@param components RegexplainerComponent[]
---@param options    RegexplainerOptions
---@return string[]
M.get_lines = require'regexplainer.renderers.narrative'.get_lines

return M
