local Utils = require'regexplainer.utils'

local keys = vim.tbl_keys

---@type RegexplainerComponentType[]
local component_types = {
  'alternation',
  'start_assertion',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'class_range',
  'control_escape',
  'decimal_escape',
  'identity_escape',
  'lookaround_assertion',
  'pattern',
  'pattern_character',
  'term',
}

-- Keys which all components share, regardless.
-- The absence of keys other than these implies that the component is simple
--
local common_keys = {
  'type',
  'text',
  'capture_depth',
}

local M = {}

for _, type in ipairs(component_types) do
  M['is_' .. type] = function(component)
    return component.type == type
  end
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_escape(component)
  return component.type == 'boundary_assertion' or component.type:match 'escape$'
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_lookaround_assertion(component)
  return component.type:find('^lookaround_assertion') ~= nil
end

-- Does a container component contain nothing by pattern_characters?
---@param component RegexplainerComponent
---@return boolean
--
function M.is_only_chars(component)
  if component.children then
    for _, child in ipairs(component.children) do
      if child.type ~= 'pattern_character' or not M.is_simple_component(component) then
        return false
      end
    end
  end
  return true
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_capture_group(component)
  local found = component.type:find('capturing_group$')
  return found ~= nil
end

function M.is_simple_component(component)
  local has_extras = false

  for _, key in ipairs(keys(component)) do
    if not has_extras then
      has_extras = not Utils.elem(key, common_keys)
    end
  end

  return not has_extras
end

--- A 'simple' component contains no children or modifiers.
--- Used e.g. to concatenate successive unmodified pattern_characters
---@param component RegexplainerComponent
---@return boolean
--
function M.is_simple_pattern_character(component)
  if not component or M.is_special_character(component) then
    return false
  end

  if M.is_identity_escape(component)
      or M.is_decimal_escape(component)
      or component.type ~= 'pattern_character' then
    return M.is_simple_component(component)
  end

  return M.is_simple_component(component)
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_special_character(component)
  return not not (component.type:find 'assertion$'
      or component.type:find 'character$'
      and component.type ~= 'pattern_character')
end

return M
