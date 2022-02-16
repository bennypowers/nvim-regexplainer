local ts_utils    = require'nvim-treesitter.ts_utils'
local highlighter = require'vim.treesitter.highlighter'

local M = {}

-- copied from nvim-treesitter/playground
local function get_treesitter_hl()
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1

  local self = highlighter.active[buf]

  if not self then
    return {}
  end

  local matches = {}

  self.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()
    local root_start_row, _, root_end_row, _ = root:range()

    -- Only worry about trees within the line range
    if root_start_row > row or root_end_row < row then
      return
    end

    local query = self:get_query(tree:lang())

    -- Some injected languages may not have highlight queries.
    if not query:query() then
      return
    end

    local iter = query:query():iter_captures(root, self.bufnr, row, row + 1)

    for capture, node, metadata in iter do
      if ts_utils.is_in_node_range(node, row, col) then
        local c = query._query.captures[capture] -- name of the capture in the query
        if c ~= nil then
          local general_hl, is_vim_hl = query:_get_hl_from_capture(capture)
          local local_hl = not is_vim_hl and (tree:lang() .. general_hl)
          local line = "* **@" .. c .. "**"
          if local_hl then
            line = line .. " -> **" .. local_hl .. "**"
          end
          if general_hl then
            line = line .. " -> **" .. general_hl .. "**"
          end
          if metadata.priority then
            line = line .. " *(priority " .. metadata.priority .. ")*"
          end
          table.insert(matches, line)
        end
      end
    end
  end, true)
  return matches
end

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

  return text
end

M.show_below = function()
  vim.notify(get_regexp_pattern_at_cursor())
end

M.is_on_regexp = function ()
  for _, match in pairs(get_treesitter_hl()) do
    if match:find('@string.regex') then
      return true
    end
  end
  return false
end

return M

