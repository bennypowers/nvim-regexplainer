local ts_utils            = require'nvim-treesitter.ts_utils'
local descriptions        = require'nvim-regexplainer.util.descriptions'
local node_pred           = require'nvim-regexplainer.util.treesitter'

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

-- Keys which all components share, regardless.
-- The absence of keys other than these implies that the component is simple
--
local common_keys = {
  'type',
  'text',
  'depth',
}

local lookuptables = {}
setmetatable(lookuptables, {__mode = "v"})  -- make values weak
local function get_lookup (xs)
  local key = table.concat(xs, '-')
  if lookuptables[key] then return lookuptables[key]
  else
    local lookup = {}
    for _, v in ipairs(xs) do lookup[v] = true end
    lookuptables[key] = lookup
    return lookup
  end
end

-- Memoized `elem` predicate
-- @param x  needle
-- @param xs haystack
--
local function elem(x, xs)
  return get_lookup(xs)[x] or false
end

for _, type in ipairs(component_types) do
  M['is_'..type] = function (component)
    return component.type == type
  end
end

function M.is_control_escape(component)
  return component.type == 'control_escape' or (
    -- `\d` and `\s` are for some reason not considered control escapes by treesitter
    component.type == 'character_class_escape' and (
      component.text:gmatch('[ds]') ~= nil
    )
  )
end

-- Does a container component contain nothing by pattern_characters?
--
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
  local found = component.type:find('capturing_group$')
  return found ~= nil
end

-- A 'simple' component contains no children or modifiers.
-- Used e.g. to concatenate successive unmodified pattern_characters
--
function M.is_simple_pattern_character(component)
  if not component or component.type ~= 'pattern_character' then
    return false
  else
    for key in pairs(component) do
      if not elem(key, common_keys) then
        return false
      end
    end
  end
  return true
end


-- keep track of how many captures we've seen
-- make sure to unset when finished an entire regexp
--
local capture_tally = 0

-- Transform a treesitter node to a table of components which are easily rendered
--
function M.make_components(node, parent, root_regex_node)
  local components = {}

  local node_type = node:type()

  if node_type == 'alternation' and node == root_regex_node then
    table.insert(components, {
      type = node_type,
      text = ts_utils.get_node_text(node)[1],
      children = {},
    })
  end

  for child in node:iter_children() do
    local type = child:type()

    local previous = components[#components]

    -- the following node types should not be added to the component tree
    -- instead, they should merely modify the previous node in the tree

    if type == 'optional'         then
      previous.optional      = true
    elseif type == 'one_or_more'      then
      previous.one_or_more   = true
    elseif type == 'zero_or_more'     then
      previous.zero_or_more  = true
    elseif type == 'count_quantifier' then
      previous.quantifier    = descriptions.describe_quantifier(child)
    elseif type == 'pattern_character'
           and M.is_simple_pattern_character(previous) then
      previous.text = previous.text .. ts_utils.get_node_text(child)[1]
    else

      -- all other node types should be added to the tree

      local component = {
        type = type,
        text = ts_utils.get_node_text(child)[1],
      }

      -- increment `depth` for each layer of capturing groups encountered
      if type:find('capturing_group$') then
        component.depth = (parent and parent.depth or 0) + 1
      end

      -- alternations are containers which do not increase depth
      if type == 'alternation' then
        component.children = M.make_components(child, nil, root_regex_node)
        table.insert(components, component)
      -- skip group_name and punctuation nodes
      elseif type ~= 'group_name' and not node_pred.is_punctuation(type) then
        if node_pred.is_container(child) then

          -- increment the capture group tally
          if type == 'named_capturing_group' or type == 'anonymous_capturing_group' then
            capture_tally = capture_tally + 1
            component.capture_group = capture_tally
          end

          if node_pred.is_named_capturing_group(child) then
            -- find the group_name and apply it to the component
            for grandchild in child:iter_children() do
              if node_pred.is_group_name(grandchild) then
                component.group_name = ts_utils.get_node_text(grandchild)[1]
                break
              end
            end
          end

          -- once state has been set above, process the children
          component.children = M.make_components(child, component, root_regex_node)
        end

        -- hack to handle top-level alternations as well as nested
        local target = components
        if node == root_regex_node and root_regex_node:type() == 'alternation' then
          target = previous.children
        end

        -- finally, append the component to the tree
        table.insert(target, component)
      end
    end
  end

  -- if we are finished processing the root regexp node,
  -- reset the capture tally for the next call
  if node == root_regex_node then
    capture_tally = 0
  end

  return components
end

return M
