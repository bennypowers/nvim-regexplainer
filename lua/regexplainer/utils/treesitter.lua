local ts_utils            = require'nvim-treesitter.ts_utils'

local M = {}

local GUARD_MAX = 1000

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
  'lookahead_assertion',
  'lookbehind_assertion',
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
  M['is_'..type] = function (node)
    if not node then return false end
    return node and node:type() == type
  end
end

-- Containers are regexp treesitter nodes which may contain leaf nodes like pattern_character.
-- An example container is anonymous_capturing_group.
--
-- @param #Node node regexp treesitter node
-- @returns boolean
--
function M. is_container(node)
  if node:child_count() == 0 then
    return false
  else
    local type = node:type()
    return (
      type == 'anonymous_capturing_group' or
      type == 'alternation'               or
      type == 'character_class'           or
      type == 'lookahead_assertion'       or
      type == 'lookbehind_assertion'      or
      type == 'named_capturing_group'     or
      type == 'non_capturing_group'       or
      type == 'pattern'                   or
      type == 'term'                      or
      false
    )
  end
end

-- For reasons the author has yet to understand, punctuation like the opening of
-- a named_capturing_group gets registered as components when traversing the tree. Let's exclude them.
--
function M.is_punctuation(type)
  return (
    type == '^'   or
    type == '('   or
    type == ')'   or
    type == '['   or
    type == ']'   or
    type == '!'   or
    type == '='   or
    type == '>'   or
    type == '|'   or
    type == '(?<' or
    type == '(?:' or
    type == '(?'  or
    false
  )
end

-- Is this the document root (or close enough for our purposes)?
--
function M.is_document(node)
  return node == nil
      or node:type() == 'program'
      or node:type() == 'document'
      or node:type() == 'source'
      or node:type() == 'source_file'
      or node:type() == 'fragment'
      or node:type() == 'chunk'
      -- if we're in an embedded language
      or node:type() == 'stylesheet'
      or node:type() == 'haskell'
      -- Wha happun?
      or node:type() == 'ERROR' and not (M.is_pattern(node:parent()) or M.is_term(node:parent()))
end

function M.is_control_escape(node)
  return require'regexplainer.component'.is_control_escape {
    type = node:type(),
    text = ts_utils.get_node_text(node)[1],
  }
end

-- Should we stop here when traversing upwards through the tree from the cursor node?
--
function M.is_upwards_stop(node)
  return node and node:type() == 'pattern' or M.is_document(node)
end

-- Is it a lookahead or lookbehind assertion?
function M.is_look_assertion(node)
  ---@see https://github.com/tree-sitter/tree-sitter-regex/issues/13
  if node:type() == 'ERROR' then
    local text = ts_utils.get_node_text(node)
    return text:match [[^%(%<]]
  else
    return require'regexplainer.component'.is_look_assertion { type = node:type() }
  end
end

function M.is_modifier(node)
  return M.is_optional(node)
      or M.is_one_or_more(node)
      or M.is_zero_or_more(node)
      or M.is_count_quantifier(node)
end

--- Using treesitter, find the current node at cursor, and traverse up to the
--- document root to determine if we're on a regexp
---@returns any, string
--
function M.get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  local cursor_node_type = cursor_node and cursor_node:type()
  if not cursor_node or cursor_node_type == 'program' then
    return nil, nil
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
          -- cribbed from get_node_at_cursor impl
          local parsers = require "nvim-treesitter.parsers"
          local root_lang_tree = parsers.get_parser(0)
          local row, col = ts_utils.get_node_range(next)

          local root = ts_utils.get_root_for_position(row, col + 1 --[[hack that works for js]], root_lang_tree)

          if not root then
            root = ts_utils.get_root_for_node(next)

            if not root then
              return nil, 'no node immediately to the right of the regexp node'
            end
          end

          node = root:named_descendant_for_range(row, col + 1, row, col + 1)
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

