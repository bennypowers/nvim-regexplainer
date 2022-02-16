local ts_utils = require'nvim-treesitter.ts_utils'

local M = {}

local function get_regexp_pattern_at_cursor()
  local node = ts_utils.get_node_at_cursor()
  local regex = node

  while regex:type() ~= 'pattern' do
    local _regex = regex
    regex = ts_utils.get_previous_node(regex, true, true)
    if not regex then
      regex = ts_utils.get_root_for_node(_regex)
    end
  end

  if not regex or regex == node then return end

  local text = ts_utils.get_node_text(regex)

  return text, regex
end

M.show_below = function()
  local pattern, regex = get_regexp_pattern_at_cursor()
  if pattern then
    -- maybe https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/split
    vim.notify(pattern)
    vim.notify(vim.inspect(regex))
  end
end

return M

