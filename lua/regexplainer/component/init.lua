local node_pred = require 'regexplainer.utils.treesitter'
local Predicates = require'regexplainer.component.predicates'
local Utils = require 'regexplainer.utils'

---@diagnostic disable-next-line: unused-local
local log = require 'regexplainer.utils'.debug

local get_node_text = vim.treesitter.get_node_text
local extend = vim.tbl_extend
local deep_extend = vim.tbl_deep_extend

---@class RegexplainerBaseComponent
---@field type            RegexplainerComponentType # Which type of component
---@field text            string                    # full text of this regexp component
---@field capture_depth   number                    # how many levels deep is this component, where 0 is top-level.
---@field quantifier?     string                    # a quantified regexp component
---@field optional?       boolean                   # a regexp component marked with `?`
---@field zero_or_more?   boolean                   # a regexp component marked with `*`
---@field one_or_more?    boolean                   # a regexp component marked with `+`
---@field lazy?           boolean                   # a regexp quantifier component marked with `?`
---@field negative?       boolean                   # when it's a negative lookaround
---@field direction?      'ahead'|'behind'          # when it's a lookaround, is it a lookahead or a lookbehind
---@field error?          any                       # parsing error

---@class RegexplainerParentComponent               : RegexplainerBaseComponent
---@field children?       (RegexplainerComponent)[] # Components may contain other components, e.g. capture groups

---@class RegexplainerCaptureGroupComponent         : RegexplainerParentComponent
---@field group_name?     string                    # the name of the capture group, if it's a named group
---@field capture_group?  number                    # which capture group does this group represent?

---@alias RegexplainerComponentType
---| 'alternation'
---| 'start_assertion'
---| 'boundary_assertion'
---| 'character_class'
---| 'character_class_escape'
---| 'class_range'
---| 'control_escape',
---| 'decimal_escape',
---| 'identity_escape',
---| 'lookaround_assertion'
---| 'pattern'
---| 'pattern_character'
---| 'term'
---| 'root'

---@alias RegexplainerComponent
---| RegexplainerBaseComponent
---| RegexplainerCaptureGroupComponent

local M = {}

-- keep track of how many captures we've seen
-- make sure to unset when finished an entire regexp
--
local capture_tally = 0


---@param node TreesitterNode
local function has_lazy(node)
  for child in node:iter_children() do
    if child:type() == 'lazy' then
      return true
    end
  end
  return false
end

---@alias TreesitterNode any

--- Transform a treesitter node to a table of components which are easily rendered
---@param bufnr           number
---@param node            TSNode
---@param parent?         RegexplainerComponent
---@param root_regex_node TSNode
---@return RegexplainerComponent[]
--
function M.make_components(bufnr, node, parent, root_regex_node)
  local text = get_node_text(node, bufnr)
  local cached = Utils.get_cached(text)
  local parent_depth = parent and parent.capture_depth or 0

  if cached then return cached end

  local components = {}

  local node_type = node:type()

  ---@return RegexplainerComponent component
  local function c(component)
    return extend('force', {
      type = 'root',
      capture_depth = parent_depth,
    }, component)
  end

  if node_type == 'alternation' and node == root_regex_node then
    table.insert(components, c {
      type = node_type,
      text = text,
      children = {},
    })
  end

  for child in node:iter_children() do
    local type = child:type()

    local child_text = get_node_text(child, bufnr)

    local previous = components[#components]

    local function append_previous(props)
      if previous.type == 'identity_escape' then
        previous.text = previous.text:gsub([[^\+]], '')
      end

      if Predicates.is_simple_pattern_character(previous) and #previous.text > 1 then
        local last_char = previous.text:sub(-1)
        if Predicates.is_identity_escape(previous)
            and Predicates.is_simple_component(previous) then
          previous.text = previous.text .. last_char
        elseif not Predicates.is_control_escape(previous)
            and not Predicates.is_character_class_escape(previous) then
          previous.text = previous.text:sub(1, -2)
          table.insert(components, c {
            type = 'pattern_character',
            text = last_char,
          })
          previous = components[#components]
        end
      end

      components[#components] = deep_extend('force', previous, props)

      return components[#components]
    end

    -- the following node types should not be added to the component tree
    -- instead, they should merely modify the previous node in the tree
    if type == 'optional' or type == 'one_or_more' or type == 'zero_or_more' then
      append_previous {
        [type] = true,
        lazy = has_lazy(child),
      }
    elseif type == 'count_quantifier' then
      append_previous {
        quantifier = require 'regexplainer.component.descriptions'.describe_quantifier(child, bufnr),
        lazy = has_lazy(child),
      }


      -- pattern characters and simple escapes can be collapsed together
      -- so long as they are not immediately followed by a modifier
    elseif type == 'pattern_character'
        and Predicates.is_simple_pattern_character(previous) then
      if previous.type == 'identity_escape' then
        previous.text = previous.text:gsub([[^\+]], '')
      end

      previous.text = previous.text .. child_text
      previous.type = 'pattern_character'
    elseif (type == 'identity_escape' or type == 'decimal_escape')
        and Predicates.is_simple_pattern_character(previous) then
      if node_type ~= 'character_class'
          and not node_pred.is_modifier(child:next_sibling()) then
        previous.text = previous.text .. child_text:gsub([[^\+]], '')
      else
        table.insert(components, c {
          type = type,
          text = child_text
        })
      end

    elseif type == 'start_assertion' then
      table.insert(components, c { type = type, text = '^' })

      -- handle errors
      --
    elseif type == 'ERROR' then
      local error_text = get_node_text(child, bufnr)
      local row, e_start, _, e_end = child:range()
      local _, re_start = node:range()
      table.insert(components, c {
        type = type,
        text = get_node_text(child, bufnr),
        error = {
          text = error_text,
          position = { row, { e_start, e_end } },
          start_offset = re_start,
        },
      })
      -- all other node types should be added to the tree
    else

      ---@type RegexplainerComponent
      local component = c {
        type = type,
        text = child_text,
      }

      -- increment `depth` for each layer of capturing groups encountered
      if type == 'pattern' or type == 'term' then
        component.capture_depth = parent_depth or 0
      elseif type:find [[capturing_group$]] then
        component.capture_depth = component.capture_depth + 1
      end

      -- negated character class
      if type == 'character_class' and component.text:find [[^%[%^]] then
        component.negative = true
        component.children = M.make_components(bufnr, child, nil, root_regex_node)
        table.insert(components, component)

        -- alternations are containers which do not increase depth
      elseif type == 'alternation' then
        component.children = M.make_components(bufnr, child, nil, root_regex_node)
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
                component.group_name = get_node_text(grandchild, bufnr)
                break
              end
            end
          end

          if node_pred.is_lookaround_assertion(child) then
            local _, _, behind, sign   = string.find(text, '%(%?(<?)([=!])')
            component.type     = type
            component.negative = sign == '!'
            component.capture_depth    = parent_depth + 1
            component.direction = behind == '<' and 'behind' or 'ahead'
          end

          -- once state has been set above, process the children
          component.children = M.make_components(bufnr, child, component, root_regex_node)

          -- FIXME: find the root cause of this weird case
          if vim.islist(component) or #component.children == 1
              and component.capture_group ~= nil
              and component.capture_group == component.children[1].capture_group then
            component = component.children[1]
          end
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

  Utils.set_cached(text, components)

  -- 😭
  for i, comp in ipairs(components) do
    if vim.islist(comp) and #comp == 1 then
      table.remove(components, i)
      components[i] = comp[1]
    end
  end

  return components
end

return M
