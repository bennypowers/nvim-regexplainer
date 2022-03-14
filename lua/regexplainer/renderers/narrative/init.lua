local narrative = require'regexplainer.renderers.narrative.narrative'

-- A textual, narrative renderer which describes a regexp in terse prose
--
local M = {}

---@param components RegexplainerComponent[]
---@param options    RegexplainerOptions
function M.get_lines(components, options)
  return narrative.recurse(components, options)
end

---@param buffer NuiBuffer
---@param lines  string[]
---@return string
function M.set_lines(buffer, lines)
  vim.api.nvim_win_call(buffer.winid, function()
    vim.lsp.util.stylize_markdown(buffer.bufnr, lines)
  end)
  return lines
end

return M
