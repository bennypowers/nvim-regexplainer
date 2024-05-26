local M = {}

local get_query = vim.treesitter.query.get
local get_parser = vim.treesitter.get_parser
local get_node_text = vim.treesitter.get_node_text
local get_node = vim.treesitter.get_node
local get_captures_at_cursor = vim.treesitter.get_captures_at_cursor
local is_in_node_range = vim.treesitter.is_in_node_range

local node_types = {
  'alternation',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'chunk',
  'class_range',
  'count_quantifier',
  'document',
  'group_name',
  'identity_escape',
  'lookaround_assertion',
  'named_capturing_group',
  'non_capturing_group',
  'one_or_more',
  'optional',
  'pattern',
  'pattern_character',
  'program',
  'source',
  'term',
  'zero_or_more',
}

for _, type in ipairs(node_types) do
  ---@type fun(node: TSNode): boolean
  M['is_' .. type] = function(node)
    if not node then
      return false
    end
    return node and node:type() == type
  end
end

---@param original_node TSNode regex_pattern node
---@return TSNode|nil, integer|nil, string|nil
local function get_pattern(original_node)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(buf, 0, 1,true, { get_node_text(original_node, 0) })
  local node
  for _, tree in ipairs(get_parser(buf, 'regex'):parse()) do
    node = tree:root()
    while node and node:type() ~= 'pattern' do
      node = node:child(0)
    end
  end
  if node and node:type() == 'pattern' then
    return node, buf, nil
  end
  return nil, buf, 'could not find pattern node'
end

function M.has_regexp_at_cursor()
  for _, cap in ipairs(get_captures_at_cursor(0)) do
    if cap == 'string.regexp' then
      return true
    end
  end
  return false
end

---Containers are regexp treesitter nodes which may contain leaf nodes like pattern_character.
---An example container is anonymous_capturing_group.
--
---@param node TSNode regexp treesitter node
---@return boolean
function M.is_container(node)
  if node:child_count() == 0 then
    return false
  else
    local type = node:type()
    return type == 'anonymous_capturing_group'
        or type == 'alternation'
        or type == 'character_class'
        or type == 'lookaround_assertion'
        or type == 'named_capturing_group'
        or type == 'non_capturing_group'
        or type == 'pattern'
        or type == 'term'
        or false
  end
end

-- For reasons the author has yet to understand, punctuation like the opening of
-- a named_capturing_group gets registered as components when traversing the tree. Let's exclude them.
--
function M.is_punctuation(type)
  return type == '^'
      or type == '('
      or type == ')'
      or type == '['
      or type == ']'
      or type == '!'
      or type == '='
      or type == '>'
      or type == '|'
      or type == '(?<'
      or type == '(?:'
      or type == '(?'
      or false
end

---@param node TSNode
---@return unknown
function M.is_control_escape(node)
  return require 'regexplainer.component'.is_control_escape {
    type = node:type(),
    text = get_node_text(node, 0),
  }
end

-- Is it a lookaround assertion?
function M.is_lookaround_assertion(node)
  return require 'regexplainer.component.predicates'.is_lookaround_assertion { type = node:type() }
end

function M.is_modifier(node)
  return M.is_optional(node)
      or M.is_one_or_more(node)
      or M.is_zero_or_more(node)
      or M.is_count_quantifier(node)
end

--- Using treesitter, find the current node at cursor, and traverse up to the
--- document root to determine if we're on a regexp
---@return TSNode|nil, integer|nil, string|nil
--
function M.get_regexp_pattern_at_cursor()
  local parser = get_parser(0)
        parser:parse()
  local query = get_query(parser:lang(), 'regexplainer')
  if not query then
    return nil, nil, 'could not load regexplainer query for ' .. parser:lang()
  end
  local cursor_node = get_node()
  if not cursor_node then
    return nil, nil, 'could not get node at cursor'
  end
  local row, col = cursor_node:range()
  for id, node in query:iter_captures(cursor_node:tree():root(), 0, row, row + 1) do
    local name = query.captures[id] -- name of the capture in the query
    if name == 'regexplainer.pattern' and is_in_node_range(node, row, col) then
      return get_pattern(node)
    end
  end
  return nil, nil, 'no node'
end

return M
