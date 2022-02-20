local M = {}

local component_types = {
  'alternation',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'class_range',
  'identity_escape',
  'pattern',
  'pattern_character',
  'term',
}

for _, type in ipairs(component_types) do
  M['is_'..type] = function (component)
    return component.type == type
  end
end

function M.is_control_escape(component)
  return component.type == 'control_escape' or (
    component.type == 'character_class_escape' and (
      component.text:gmatch('[ds]') ~= nil
    )
  )
end

function M.is_only_chars(component)
  if component.children then
    for _, child in ipairs(component.children) do
      if child.type ~= 'pattern_character' then
        return false
      end
    end
  end
  return true
end

function M.is_capture_group(component)
  if not component.type then
    vim.notify(vim.inspect(component))
  end
  local found = component.type:find('capturing_group$')
  return found ~= nil
end

function M.is_simple_pattern_character(component)
  if not component or component.type ~= 'pattern_character' then
    return false
  else
    for key in pairs(component) do
      print(key)
      if (not (key == 'text' or key == 'type')) then
        return false
      end
    end
  end
  return true
end

function M.is_named_capturing_group(node)
  return node:type() == 'named_capturing_group'
end

function M.is_non_capturing_group(node)
  return node:type() == 'non_capturing_group'
end

function M.is_group_name(node)
  return node:type() == 'group_name'
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
