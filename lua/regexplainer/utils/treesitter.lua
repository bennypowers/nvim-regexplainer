local ts_utils = require 'nvim-treesitter.ts_utils'

local M = {}

local GUARD_MAX = 1000

local get_node_text = vim.treesitter.get_node_text or vim.treesitter.query.get_node_text

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
  M['is_' .. type] = function(node)
    if not node then return false end
    return node and node:type() == type
  end
end

---Enter a parent-language's regexp node which contains the embedded
---regexp grammar
---@param node TreesitterNode
local function enter_js_re_node(node)
  -- cribbed from get_node_at_cursor impl
  local parsers = require 'nvim-treesitter.parsers'
  local root_lang_tree = parsers.get_parser(0)
  local row, col = vim.treesitter.get_node_range(node)

  local root = ts_utils.get_root_for_position(row, col + 1--[[hack that works for js]] , root_lang_tree)

  if not root then
    root = ts_utils.get_root_for_node(node)

    if not root then
      return nil, 'no node immediately to the right of the regexp node'
    end
  end

  return root:named_descendant_for_range(row, col + 1, row, col + 1)
end

---Containers are regexp treesitter nodes which may contain leaf nodes like pattern_character.
---An example container is anonymous_capturing_group.
--
---@param node TreesitterNode regexp treesitter node
---@return boolean
--
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

-- Is this the document root (or close enough for our purposes)?
--
function M.is_document(node)
  if node == nil then return true else
    local type = node:type()
    return type == 'program'
        or type == 'document'
        or type == 'source'
        or type == 'source_file'
        or type == 'fragment'
        or type == 'chunk'
        -- if we're in an embedded language
        or type == 'stylesheet'
        or type == 'haskell'
        -- Wha happun?
        or type == 'ERROR' and not (M.is_pattern(node:parent()) or M.is_term(node:parent()))
  end
end

function M.is_control_escape(node)
  return require 'regexplainer.component'.is_control_escape {
    type = node:type(),
    text = get_node_text(node, 0),
  }
end

-- Should we stop here when traversing upwards through the tree from the cursor node?
--
function M.is_upwards_stop(node)
  return node and node:type() == 'pattern' or M.is_document(node)
end

-- Is it a lookaround assertion?
function M.is_lookaround_assertion(node)
  return require 'regexplainer.component'.is_lookaround_assertion { type = node:type() }
end

function M.is_modifier(node)
  return M.is_optional(node)
      or M.is_one_or_more(node)
      or M.is_zero_or_more(node)
      or M.is_count_quantifier(node)
end

--- Using treesitter, find the current node at cursor, and traverse up to the
--- document root to determine if we're on a regexp
---@return any, string|nil
--
function M.get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  local cursor_node_type = cursor_node and cursor_node:type()
  if not cursor_node or cursor_node_type == 'program' then
    return
  end

  local node = cursor_node

  if node:type() == 'regex' then
    local iterator = node:iter_children()

    -- break if we enter an infinite loop (probably)
    --
    local guard = 0
    while node == cursor_node do
      guard = guard + 1
      if guard >= GUARD_MAX then
        return nil, 'loop exceeded ' .. GUARD_MAX .. ' at node ' .. (node and node:type() or 'nil')
      end

      local next = iterator()

      if not next then
        return nil, 'no downwards node'
      else
        local type = next:type()

        if type == 'pattern' then
          node = next
        elseif type == 'regex_pattern' or type == 'regex' then
          node = enter_js_re_node(next)
        end
      end
    end
  end

  -- break if we enter an infinite loop (probably)
  --
  local guard = 0
  while not M.is_upwards_stop(node) do
    guard = guard + 1
    if guard >= GUARD_MAX then
      return nil, 'loop exceeded ' .. GUARD_MAX .. ' at node ' .. (node and node:type() or 'nil')
    end

    local _node = node
    node = ts_utils.get_previous_node(node, true, true)
    if not node then
      node = ts_utils.get_root_for_node(_node)
      if not node then
        return nil, 'no upwards node'
      end
    end
  end

  if M.is_document(node) then
    return nil, nil
  elseif node == cursor_node then
    return nil, 'stuck on cursor_node'
  elseif not node then
    return nil, 'unexpected no downwards node'
  end

  return node, nil
end

return M
