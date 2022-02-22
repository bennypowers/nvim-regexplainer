local ts_utils            = require'nvim-treesitter.ts_utils'

local M = {}

local node_types = {
  'alternation',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'chunk',
  'class_range',
  'document',
  'group_name',
  'identity_escape',
  'lookahead_assertion',
  'lookbehind_assertion',
  'named_capturing_group',
  'non_capturing_group',
  'pattern',
  'pattern_character',
  'program',
  'source',
  'term',
}

for _, type in ipairs(node_types) do
  M['is_'..type] = function (node)
    return node:type() == type
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

function M.is_control_escape(node)
  return require'nvim-regexplainer.util.component'.is_control_escape {
    type = node:type(),
    text = ts_utils.get_node_text(node)[1],
  }
end

-- Is this the document root (or close enough for our purposes)?
--
function M.is_document(node)
  return node
     and node:type() == 'chunk'
      or node:type() == 'program'
      or node:type() == 'document'
      or node:type() == 'source'
end

-- Should we stop here when traversing upwards through the tree from the cursor node?
--
function M.is_upwards_stop(node)
  return node:type() == 'pattern' or M.is_document(node)
end

-- Is it a lookahead or lookbehind assertion?
function M.is_look_assertion(node)
  return require'nvim-regexplainer.util.component'.is_look_assertion { type = node:type() }
end

return M

