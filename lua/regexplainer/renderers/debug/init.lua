--- A debug renderer that outputs the component tree
---@type RegexplainerRenderer
--
local M = {}

---@param buffer RegexplainerBuffer
---@param lines  string[]
---@return string[]
function M.set_lines(buffer, lines)
  vim.api.nvim_win_call(buffer.winid, function()
    vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, lines)
    vim.bo.filetype = 'lua'
  end)
  return lines
end

---@param components RegexplainerComponent[]
---@param _          RegexplainerOptions
---@param state      RegexplainerRendererState
---@return string[]
function M.get_lines(components, _, state)
  local lines = {}
  local text =
  'local regexp_string = [['
      .. state.full_regexp_text
      .. ']]\n'
      .. 'local components = '
      .. vim.inspect(components)

  for line in text:gmatch '([^\n]*)\n?' do
    table.insert(lines, line)
  end

  return lines
end

return M
