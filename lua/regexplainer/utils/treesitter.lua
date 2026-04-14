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
---@param processing? string 'string'|'delimited'|nil
---@return TSNode|nil, integer|nil, string|nil
function M.get_pattern(original_node, processing)
  local text = get_node_text(original_node, 0)
  if processing == 'string' then
    text = M.process_string_literal(text)
  elseif processing == 'delimited' then
    text = M.strip_regex_delimiters(text)
  end
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_lines(buf, 0, 1, true, { text })
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
  local node = M.get_regex_node_at_cursor()
  return node ~= nil
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

--- Process a string literal to extract the regex pattern.
--- Strips surrounding quotes if present, then unescapes string escape sequences.
---@param text string
---@return string
function M.process_string_literal(text)
  -- Handle C# verbatim strings: @"..."
  if text:sub(1, 2) == '@"' and text:sub(-1) == '"' then
    text = text:sub(3, -2)
    return (text:gsub('""', '"'))
  end
  -- Strip surrounding quotes if present
  local first = text:sub(1, 1)
  if (first == '"' or first == "'") and text:sub(-1) == first then
    text = text:sub(2, -2)
  end
  -- Unescape string escape sequences: \X -> X
  return (text:gsub('\\(.)', '%1'))
end

--- Strip regex delimiters from a pattern string.
--- Handles /pattern/flags format used by Ruby regex literals and PHP PCRE strings.
---@param text string
---@return string
function M.strip_regex_delimiters(text)
  return text:match('^/(.*)/[A-Za-z]*$') or text
end

--- Using treesitter, find the current node at cursor
---@return TSNode|nil, string|nil error, string|nil processing
--
function M.get_regex_node_at_cursor()
  local parser = get_parser(0)
        parser:parse()
  local query = get_query(parser:lang(), 'regexplainer')

  if query then
    local cursor_node = get_node()
    if cursor_node then
      local row, col = cursor_node:range()
      for id, node in query:iter_captures(cursor_node:tree():root(), 0, row, row + 1) do
        local name = query.captures[id]
        if is_in_node_range(node, row, col) then
          if name == 'regexplainer.pattern' then
            return node
          elseif name == 'regexplainer.string_pattern' then
            return node, nil, 'string'
          elseif name == 'regexplainer.delimited_pattern' then
            return node, nil, 'delimited'
          end
        end
      end
    end
  end

  -- Fallback: check for injected regex tree at cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_row, cursor_col = cursor[1] - 1, cursor[2]
  local range = { cursor_row, cursor_col, cursor_row, cursor_col }
  local ok, lang_tree = pcall(parser.language_for_range, parser, range)
  if ok and lang_tree and lang_tree:lang() == 'regex' then
    local regex_query = get_query('regex', 'regexplainer')
    if regex_query then
      for _, injected_tree in ipairs(lang_tree:trees()) do
        for id, node in regex_query:iter_captures(injected_tree:root(), 0) do
          if regex_query.captures[id] == 'regexplainer.pattern'
              and is_in_node_range(node, cursor_row, cursor_col) then
            return node
          end
        end
      end
    end
  end

  return nil, 'no node'
end

--- Using treesitter, find the current node at cursor, and traverse up to the
--- document root to determine if we're on a regexp
---@return TSNode|nil, integer|nil, string|nil
--
function M.get_regexp_pattern_at_cursor()
  local node, err, processing = M.get_regex_node_at_cursor()
  if node then
    return M.get_pattern(node, processing)
  end
  return nil, nil, err
end

return M
