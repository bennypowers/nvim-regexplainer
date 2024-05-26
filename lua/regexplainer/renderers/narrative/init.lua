local narrative = require 'regexplainer.renderers.narrative.narrative'
local buffers   = require 'regexplainer.buffers'

-- A textual, narrative renderer which describes a regexp in terse prose
--
local M = {}

---@param components RegexplainerComponent[]
---@param options    RegexplainerOptions
---@param state      RegexplainerNarrativeRendererState
function M.get_lines(components, options, state)
  local lines = narrative.recurse(components, options, state)
  return lines
end

---@param buffer RegexplainerBuffer
---@param lines  string[]
---@return string[]
function M.set_lines(buffer, lines)
  if buffers.is_scratch(buffer) then
    vim.api.nvim_buf_set_lines(buffer.bufnr, 0, #lines, false, lines)
  elseif buffer.winid then
    vim.api.nvim_win_call(buffer.winid, function()
      vim.lsp.util.stylize_markdown(buffer.bufnr, lines, {})
    end)
  end
  return lines
end

return M
