local M = {}

local component_types = {
  'alternation',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'named_capturing_group',
  'non_capturing_group',
  'class_range',
  'identity_escape',
  'group_name',
  'pattern',
  'pattern_character',
  'term',
}

for _, type in ipairs(component_types) do
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
function M. is_punctuation(type)
  return (
    type == '('   or
    type == ')'   or
    type == '['   or
    type == ']'   or
    type == '(?<' or
    type == '>'   or
    type == '|'   or
    false
  )
end

return M
