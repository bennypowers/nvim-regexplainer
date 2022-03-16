local descriptions           = require'regexplainer.component.descriptions'
local component_pred         = require'regexplainer.component'
local utils                  = require'regexplainer.utils'

local M = {}

---@class RegexplainerNarrativeRendererOptions
---@field separator string|fun(component: Component): string # clause separator

---@class RegexplainerNarrativeRendererState : RegexplainerRendererState
---@field depth            number  # tracker for component depth
---@field lookbehind_found boolean # see https://github.com/tree-sitter/tree-sitter-regex/issues/13
---@field first            boolean # is it first in the term?
---@field last             boolean # is it last in the term?

--- Get a suffix describing the component's quantifier, optionality, etc
---@param component RegexplainerComponent
---@return string
--
local function get_suffix(component)
  local suffix = ''

  if component.quantifier then
    suffix = ' (_' .. component.quantifier .. '_)'
  end

  if     component.optional then
    suffix = suffix .. ' (_optional_)'
  elseif component.zero_or_more then
    suffix = suffix .. ' (_>= 0x_)'
  elseif component.one_or_more then
    suffix = suffix .. ' (_>= 1x_)'
  end

  return suffix
end

--- Get a title for a group component
---@param component RegexplainerComponent
---@return string
--
local function get_group_heading(component)
  local name = component.group_name and ('`'..component.group_name..'`') or ''

  return (component.type == 'named_capturing_group' and 'named capture group ' .. component.capture_group .. ' ' .. name
       or component.type == 'non_capturing_group' and 'non-capturing group '
       or 'capture group '.. component.capture_group):gsub(' $', '')
end

---@param orig_sep  string                # the original configured separator string
---@param component RegexplainerComponent # component to render
---@return string                         # the next separator string
local function default_sep(orig_sep, component)
  local sep = orig_sep;
  if component.depth > 0 then

    for _ = 1, component.depth do
      sep = sep .. '  '
    end
  end
  return sep
end

--- Get all lines for a recursive component's children
---@param component RegexplainerComponent
---@param options   RegexplainerOptions
---@param state     RegexplainerNarrativeRendererState
---@return string[], string
--
local function get_sublines(component, options, state)
  local depth = (state.depth or 0)

  local sep = options.narrative.separator

  if type(options.narrative.separator) == "function" then
    sep = options.narrative.separator(component)
  else
    sep = default_sep(sep or '\n', component)
  end

  local children = component.children
  while (#children == 1 and (   component_pred.is_term(children[1])
                             or component_pred.is_pattern(children[1]))) do
    children = children[1].children
  end

  return M.recurse(children, options, vim.tbl_deep_extend('force', state, {
    depth = (state.depth or 0) + 1,
  })), sep
end

--- Get a narrative clause for a component and all it's children
--- i.e. a single top-level narrative unit
---@param component RegexplainerComponent
---@param options   RegexplainerOptions
---@param state     RegexplainerNarrativeRendererState
---@return string
--
local function get_narrative_clause(component, options, state)
  local prefix = ''
  local infix = ''
  local suffix = ''

  if state.first and not state.last then
    prefix = ''
  elseif not state.depth and state.last and not state.first then
    prefix = ''
  end

  if component_pred.is_alternation(component) then
    for i, child in ipairs(component.children) do
      local oxford = i == #component.children and 'or ' or ''
      local first_in_alt = i == 1
      local last_in_alt = i == #component.children
      prefix = 'Either '
      infix = infix
              .. (first_in_alt and '' or #component.children == 2 and ' ' or ', ')
              .. oxford
              .. get_narrative_clause(child, options, vim.tbl_extend('force', state, {
                                        first = first_in_alt,
                                        last = last_in_alt,
                                      }))
    end
  end

  if component_pred.is_term(component) or component_pred.is_pattern(component) then
    if component_pred.is_only_chars(component) then
      infix = '`' .. component.text .. '`'
    else
      for _, child in ipairs(component.children) do
        infix = infix .. get_narrative_clause(child, options, state)
      end
    end
  end

  if component_pred.is_pattern_character(component) then
    infix = '`' .. utils.escape_markdown(component.text) .. '`'
  end

  if component_pred.is_identity_escape(component) then
    infix = '`' .. component.text:sub(2) .. '`'

  elseif component_pred.is_special_character(component) then
    infix = '**' .. utils.escape_markdown(descriptions.describe_character(component)) .. '**'

  elseif component_pred.is_escape(component) then
    local char = component.text:sub(2)
    local desc = descriptions.describe_escape(char) or char
    infix = '**' .. desc .. '**'
  end

  if component_pred.is_boundary_assertion(component) then
    infix = '**WB**'
  end

  if component_pred.is_character_class(component) then
    infix = descriptions.describe_character_class(component)
  end

  if component_pred.is_capture_group(component) then
    local sublines, sep = get_sublines(component, options, state)
    local contents = table.concat(sublines, sep):gsub(sep .. '$', '')

    infix =
         get_group_heading(component)
      .. get_suffix(component)
      .. ':'
      .. sep
      .. contents
      .. '\n'

  end

  if component_pred.is_look_assertion(component) then
    if component.type == 'lookbehind_assertion' then
      state.lookbehind_found = true
    end

    local negation = component.negative and 'NOT ' or ''
    local direction = component_pred.is_lookahead_assertion(component) and 'followed by' or 'preceeding'
    prefix = '**' .. negation .. direction .. ' ' .. '**'

    local sublines, sep = get_sublines(component, options, state)
    local contents = table.concat(sublines, sep):gsub(sep .. '$', '')

    infix =
         get_suffix(component)
      .. ':'
      .. sep
      .. contents
      .. '\n'
  end

  if not component_pred.is_capture_group(component)
     and not component_pred.is_look_assertion(component) then
    suffix = get_suffix(component)
  end

  return prefix .. infix .. suffix
end

---@param components RegexplainerComponent[]
---@param options    RegexplainerOptions
---@param state      RegexplainerNarrativeRendererState
function M.recurse(components, options, state)
  state = state or {}
  local clauses = {}
  local lines   = {}

  for i, component in ipairs(components) do
    local first = i == 1
    local last = i == #components
    if component.type == 'ERROR' then
      lines[1] = '🚨 **Regexp contains an ERROR** at'
      lines[2] = '`' .. state.full_regexp_text ..  '`'
      lines[3] = ' '
      local error_start_col = component.error.position[2][1]
      local from_re_start_to_err_start = error_start_col - component.error.start_offset + 1
      for _ = 1, from_re_start_to_err_start do
        lines[3] = lines[3] .. ' '
      end
      lines[3] = lines[3] .. '^'
      return lines, state
    end

    local next_clause = get_narrative_clause(component,
                                             options,
                                             vim.tbl_extend('force', state, {
                                               first = first,
                                               last = last,
                                             }))

    if component_pred.is_lookahead_assertion(component) then
      clauses[#clauses] = clauses[#clauses] .. ' ' .. next_clause
    else
      table.insert(clauses, next_clause)
    end
  end

  local separator = options.narrative.separator
  if type(separator) == "function" then
    separator = separator({ type = 'root', depth = 0 })
  end

  local narrative = table.concat(clauses, separator)

  for line in narrative:gmatch("([^\n]*)\n?") do
    if #line > 0 then
      table.insert(lines, line)
    end
  end

  return lines, state
end

return M