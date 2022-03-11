local ts_utils            = require'nvim-treesitter.ts_utils'
local node_pred           = require'regexplainer.utils.treesitter'

---@class RegexplainerBaseComponent
---@field type            RegexplainerComponentType # Which type of component
---@field text            string                    # full text of this regexp component
---@field depth           number                    # how many levels deep is this component, where 0 is top-level.
---@field quantifier?     string                    # a quantified regexp component
---@field optional?       boolean                   # a regexp component marked with `?`
---@field zero_or_more?   boolean                   # a regexp component marked with `*`
---@field one_or_more?    boolean                   # a regexp component marked with `+`

---@class RegexplainerParentComponent               : RegexplainerBaseComponent
---@field children?       RegexplainerComponent     # Components may contain other components, e.g. capture groups

---@class RegexplainerCaptureGroupComponent         : RegexplainerParentComponent
---@field group_name?     boolean                   # a regexp component marked with `+`
---@field capture_group?  number                    # which capture group does this group represent?

---@alias RegexplainerComponentType
---| "'alternation'"
---| "'boundary_assertion'"
---| "'lookahead_assertion'"
---| "'character_class'"
---| "'character_class_escape'"
---| "'class_range'"
---| "'pattern'"
---| "'pattern_character'"
---| "'term'"

---@alias RegexplainerComponent
---| "RegexplainerBaseComponent"
---| "RegexplainerCaptureGroupComponent"

local M = {}

---@type RegexplainerComponentType[]
local component_types = {
  'alternation',
  'boundary_assertion',
  'lookahead_assertion',
  'character_class',
  'character_class_escape',
  'class_range',
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

-- keep track of how many captures we've seen
-- make sure to unset when finished an entire regexp
--
local capture_tally = 0

local lookuptables = {}
setmetatable(lookuptables, {__mode = "v"})  -- make values weak
local function get_lookup (xs)
  local key = type(xs) == 'string' and xs or table.concat(xs, '-')
  if lookuptables[key] then return lookuptables[key]
  else
    local lookup = {}
    for _, v in ipairs(xs) do lookup[v] = true end
    lookuptables[key] = lookup
    return lookup
  end
end

--- Memoized `elem` predicate
---@generic T
---@param x  T   needle
---@param xs T[] haystack
--
local function elem(x, xs)
  return get_lookup(xs)[x] or false
end

for _, type in ipairs(component_types) do
  M['is_'..type] = function (component)
    return component.type == type
  end
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_control_escape(component)
  return component.type == 'control_escape' or (
    -- `\d` and `\s` are for some reason not considered control escapes by treesitter
    component.type == 'character_class_escape' and (
      component.text:gmatch('[ds]') ~= nil
    )
  )
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_identity_escape(component)
  return component.type == 'identity_escape'
      -- `\d` and `\s` are for some reason considered identity escapes by treesitter
     and component.text:gmatch('[ds]') == nil
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_look_assertion(component)
  return component.type:find('^look%a+_assertion') ~= nil
end

-- Does a container component contain nothing by pattern_characters?
---@param component RegexplainerComponent
---@return boolean
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

---@param component RegexplainerComponent
---@return boolean
--
function M.is_capture_group(component)
  local found = component.type:find('capturing_group$')
  return found ~= nil
end

--- A 'simple' component contains no children or modifiers.
--- Used e.g. to concatenate successive unmodified pattern_characters
---@param component RegexplainerComponent
---@return boolean
--
function M.is_simple_pattern_character(component)
  if not component or M.is_special_character(component) then
    return false
  elseif M.is_identity_escape(component) then
    return true
  elseif component.type ~= 'pattern_character' then
    for key in pairs(component) do
      if not elem(key, common_keys) then
        return false
      end
    end
  end
  return true
end

---@param component RegexplainerComponent
---@return boolean
--
function M.is_special_character(component)
  return component.type:find'assertion$'
      or component.type:find'character$'
     and component.type ~= 'pattern_character'
end

---@alias TreesitterNode any

--- Transform a treesitter node to a table of components which are easily rendered
---@param node            TreesitterNode
---@param parent?         TreesitterNode
---@param root_regex_node TreesitterNode
---@return RegexplainerComponent[]
--
function M.make_components(node, parent, root_regex_node)
  local text = ts_utils.get_node_text(node)[1]
  local cached = lookuptables[text]
  if cached then return cached end

  local components = {}

  local node_type = node:type()

  if node_type == 'alternation' and node == root_regex_node then
    table.insert(components, {
      type = node_type,
      text = text,
      children = {},
    })
  end

  for child in node:iter_children() do
    local type = child:type()

    local previous = components[#components]

    local function append_previous(props)
      if M.is_simple_pattern_character(previous) and #previous.text > 1 then
        local last_char = previous.text:sub(-1)
        previous.text = previous.text:sub(1, -2)
        previous.type = 'pattern_character'
        table.insert(components, { type = 'pattern_character', text = last_char })
        previous = components[#components]
      end
      components[#components] = vim.tbl_deep_extend('force', previous, props)
      return previous
    end

    -- the following node types should not be added to the component tree
    -- instead, they should merely modify the previous node in the tree
    if type == 'optional' or type == 'one_or_more' or type == 'zero_or_more' then
      append_previous { [type] = true }
    elseif type == 'count_quantifier' then
      append_previous {
        quantifier = require'regexplainer.component.descriptions'.describe_quantifier(child),
      }

    -- pattern characters and simple escapes can be collapsed together
    -- so long as they are not immediately followed by a modifier
    elseif type == 'pattern_character'
           and M.is_simple_pattern_character(previous) then
      previous.text = previous.text .. ts_utils.get_node_text(child)[1]
    elseif type == 'identity_escape'
           and not node_pred.is_control_escape(child)
           and M.is_simple_pattern_character(previous) then
      previous.text = previous.text .. ts_utils.get_node_text(child)[1]:sub(1, -1)

    elseif type == 'start_assertion' then
      table.insert(components, { type = type, text = '^' })

    -- handle errors
    -- treesitter does not appear to support js lookbehinds
    -- see https://github.com/tree-sitter/tree-sitter-javascript/issues/214
    --
    elseif type == 'ERROR' then
      local error_text = ts_utils.get_node_text(child)[1]
      local row, e_start, _, e_end = child:range()
      local _, re_start = node:range()

      -- TODO: until treesitter supports lookbehind, we can parse it ourselves
      -- This code, however, is not ready to use

      -- local from_re_start_to_err_start = e_start - re_start + 1
      --
      -- local error_term_text = text:sub(from_re_start_to_err_start)
      --
      -- local is_lookbehind = error_term_text:find[[^%(%?<!?]]
      --
      -- if is_lookbehind ~= nil then
      --   local is_negative = error_term_text:find[[%(%?<!]]
      --   table.insert(components, {
      --     type = 'lookbehind_assertion',
      --     text = error_term_text,
      --     negative = is_negative ~= nil,
      --     depth = (parent and parent.depth or 0) + 1,
      --     children = M.make_components(child, nil, root_regex_node)
      --   })
      -- else
        table.insert(components, {
          type = type,
          text = ts_utils.get_node_text(child)[1],
          error = {
            text = error_text,
            position = { row, { e_start, e_end } },
            start_offset = re_start,
          },
        })
      -- end
    -- all other node types should be added to the tree
    else

      local component = {
        type = type,
        text = ts_utils.get_node_text(child)[1],
      }

      -- increment `depth` for each layer of capturing groups encountered
      if type:find[[capturing_group$]] then
        component.depth = (parent and parent.depth or 0) + 1
      end

      -- negated character class
      if type == 'character_class' and component.text:find[[^%[%^]] then
        component.negative = true
        component.children = M.make_components(child, nil, root_regex_node)
        table.insert(components, component)

      -- alternations are containers which do not increase depth
      elseif type == 'alternation' then
        component.children = M.make_components(child, nil, root_regex_node)
        table.insert(components, component)

      -- skip group_name and punctuation nodes
      elseif type ~= 'group_name'
         and not node_pred.is_punctuation(type) then
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

          if node_pred.is_look_assertion(child) then
            local _, _, sign  = string.find(text, '%(%?<?([=!])')
            component.type = type
            component.negative = sign == '!'
            component.depth = (parent and parent.depth or 0) + 1
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

  lookuptables[text] = components

  return components
end

return M
