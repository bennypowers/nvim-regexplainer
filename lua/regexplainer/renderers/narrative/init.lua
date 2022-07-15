local narrative = require 'regexplainer.renderers.narrative.narrative'
local buffers   = require 'regexplainer.buffers'

-- A textual, narrative renderer which describes a regexp in terse prose
--
local M = {}

local function check_for_lookbehind(components)
  for _, component in ipairs(components) do
    if component.type == 'lookbehind_assertion' or check_for_lookbehind(component.children or {}) then
      return true
    end
  end
  return false
end

---@param components RegexplainerComponent[]
---@param options    RegexplainerOptions
---@param state      RegexplainerRendererState
function M.get_lines(components, options, state)
  local lines = narrative.recurse(components, options, state)
  local found = check_for_lookbehind(components)
  if found then
    table.insert(lines, 1, '⚠️ **Lookbehinds are poorly supported**')
    table.insert(lines, 2, '⚠️ results may not be accurate')
    table.insert(lines, 3, '⚠️ See https://github.com/tree-sitter/tree-sitter-regex/issues/13')
    table.insert(lines, 4, '')
  end
  return lines
end

---@param buffer NuiBuffer
---@param lines  string[]
---@return string
function M.set_lines(buffer, lines)
  if buffers.is_scratch(buffer) then
    vim.api.nvim_buf_set_lines(buffer.bufnr, 0, #lines, false, lines)
  else
    vim.api.nvim_win_call(buffer.winid, function()
      vim.lsp.util.stylize_markdown(buffer.bufnr, lines)
    end)
  end
  return lines
end

return M
