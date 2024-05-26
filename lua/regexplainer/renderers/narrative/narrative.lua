local D = require'regexplainer.component.descriptions'
local P = require'regexplainer.component.predicates'
local U = require'regexplainer.utils'

local extend = function(a, b) return vim.tbl_extend('force', a, b) end

local M = {}

---@class RegexplainerNarrativeRendererOptions
---@field indentation_string string|fun(component:RegexplainerComponent):string # clause separator

---@class RegexplainerNarrativeRendererState : RegexplainerRendererState
---@field first            boolean # is it first in the term?
---@field last             boolean # is it last in the term?
---@field parent           RegexplainerComponent the parent component

--- Get a description of the component's quantifier, optionality, etc
---@param component RegexplainerComponent
---@return string
--
local function get_quantifier(component)
  local quant = ''

  if component.quantifier then
    quant = ' (_' .. component.quantifier .. '_)'
  end

  if component.optional then
    quant = quant .. ' (_optional_)'
  elseif component.zero_or_more then
    quant = quant .. ' (_>= 0x_)'
  elseif component.one_or_more then
    quant = quant .. ' (_>= 1x_)'
  end

  if component.lazy then
    quant = quant .. ' (_lazy_)'
  end

  return quant
end

---@param component RegexplainerComponent # component to render
---@param options   RegexplainerOptions   # the original configured separator string
---@return string                         # the next separator string
local function get_indent_string(component, options)
  local indent = options.narrative.indentation_string
  if component.type == 'pattern' or component.type == 'term' then
    return ''
  elseif type(indent) == "function" then
    return indent(component)
  else
    return indent
  end
end

--- Get a description of the component's quantifier, optionality, etc
---@param component RegexplainerComponent
---@param options   RegexplainerOptions
---@param state     RegexplainerNarrativeRendererState
---@return string
--
local function get_prefix(component, options, state)
  local prefix = ''

  if state.first and not state.last then
    prefix = ''
  elseif state.last and not state.first then
    prefix = ''
  end

  if P.is_alternation(component) then
    prefix = 'Either '
  end

  if component.optional or component.quantifier then
    prefix = prefix .. '\n'
  end

  return prefix
end

--- Get a suffix for the current clause
---@param component RegexplainerComponent
---@param options   RegexplainerOptions
---@param state     RegexplainerNarrativeRendererState
---@return string
--
local function get_suffix(component, options, state)
  local suffix = ''
  if not P.is_capture_group(component) and not P.is_lookaround_assertion(component) then
    suffix = get_quantifier(component)
  end
  if component.zero_or_more or component.quantifier or component.one_or_more then
    suffix = suffix .. '\n'
  end
  return suffix
end

---@param component RegexplainerComponent
---@param options   RegexplainerOptions
---@param state     RegexplainerNarrativeRendererState
---@return string
--
local function get_infix(component, options, state)
  if P.is_term(component) or P.is_pattern(component) then
    if P.is_only_chars(component) then
      return '`' .. component.text .. '`'
    else
      local sep = get_indent_string(component, options)
      local line_sep = P.is_alternation(state.parent) and '' or '\n'
      local sublines = M.recurse(component.children, options, state)
      local contents = table.concat(sublines, '\n')
      return ''
        .. get_quantifier(component)
        .. line_sep
        .. string.rep(sep, component.capture_depth)
        .. line_sep
        .. contents
        .. line_sep
    end
  end

  if P.is_alternation(component) then
    -- we have to do alternations by iterating instead of recursing
    local infix = ''
    for i, child in ipairs(component.children) do
      local oxford = i == #component.children and 'or ' or ''
      local first_in_alt = i == 1
      local last_in_alt = i == #component.children
      local next_state = extend(state, {
        first = first_in_alt,
        last = last_in_alt,
        parent = component
      })
      infix = infix
          .. (first_in_alt and '' or #component.children == 2 and ' ' or ', ')
          .. oxford
          .. get_prefix(child, options, next_state)
          .. get_infix(child, options, next_state)
          .. get_suffix(child, options, next_state)
    end
    return infix
  end

  if P.is_capture_group(component) then
    local indent = get_indent_string(component, options)
    local sublines = M.recurse(component.children, options, extend(state, {
      parent = component
    }))
    local contents = table.concat(sublines, '\n' .. indent)
    local name = component.group_name and ('`' .. component.group_name .. '`') or ''
    local header = ''
    if component.type == 'named_capturing_group' then
      header = 'named capture group ' .. component.capture_group .. ' ' .. name
    elseif component.type == 'non_capturing_group' then
      header = 'non-capturing group '
    else
      header = 'capture group ' .. component.capture_group
    end
    header = header:gsub(' $', '')
    return ''
      .. header
      .. get_quantifier(component)
      .. ':\n'
      .. indent
      .. contents
  end

  if P.is_character_class(component) then
    return '\n' .. D.describe_character_class(component)
  end

  if P.is_escape(component) then
    if P.is_identity_escape(component) then
      local text = component.text:sub(2)
      if text == '' then text = component.text end
      local escaped_text = U.escape_markdown(text)
      if escaped_text == ' ' then escaped_text = '(space)' end
      return '`' .. escaped_text .. '`'
    elseif P.is_decimal_escape(component) then
      return '`' .. D.describe_escape(component.text) .. '`'
    else
      return '**' .. D.describe_escape(component.text) .. '**'
    end
  end

  if P.is_character_class_escape(component) then
    return '**' .. D.describe_escape(component.text) .. '**'
  end

  if P.is_pattern_character(component) then
    return '`' .. U.escape_markdown(component.text) .. '`'
  end

  if P.is_lookaround_assertion(component) then
    local indent = get_indent_string(component, options)
    local sublines = M.recurse(component.children, options, extend(state, {
      parent = component
    }))
    local contents = table.concat(sublines, '\n'..indent)

    local negation = (component.negative and 'NOT ' or '')
    local direction = 'followed by'
    if component.direction == 'behind' then
      direction = 'preceeding'
    end

    return ''
      .. '**'
      .. negation
      .. direction
      .. '**'
      .. get_quantifier(component)
      .. ':\n'
      .. string.rep(indent, component.capture_depth)
      .. contents
      .. '\n'
  end

  if P.is_special_character(component) then
    local infix = ''
    infix = infix .. '**' .. D.describe_character(component) .. '**'
    if P.is_start_assertion(component) then
      infix = infix .. '\n'
    end
    return infix
  end

  if P.is_boundary_assertion(component) then
    return '**WB**'
  end
end

---@param component RegexplainerComponent
---@return nil|RegexplainerComponent error
local function find_error(component)
  local error
  if component.type == 'ERROR' then
    error = component
  elseif component.children then
    for _, child in ipairs(component.children) do
      error = find_error(child)
      if error then return error end
    end
  end
  return error
end

local function get_error_message(error, state)
  local lines = {}
  lines[1] = '🚨 **Regexp contains an ERROR** at'
  lines[2] = '`' .. state.full_regexp_text .. '`'
  lines[3] = ' '
  local error_start_col = error.error.position[2][1]
  local from_re_start_to_err_start = error_start_col - error.error.start_offset + 1
  for _ = 1, from_re_start_to_err_start do
    lines[3] = lines[3] .. ' '
  end
  lines[3] = lines[3] .. '^'
  return lines
end

local function is_non_empty(line)
  return line ~= ''
end

local function split_lines(clause)
  return vim.split(clause, '\n')
end

local function trim_end(str)
  local s = str:gsub(' +$', '')
  return s
end

---@param components (RegexplainerComponent)[]
---@param options    RegexplainerOptions
---@param state      RegexplainerNarrativeRendererState
---@return string[] lines, RegexplainerNarrativeRendererState state
function M.recurse(components, options, state)
  local clauses = {}
  for i, component in ipairs(components) do
    local first = i == 1
    local last = i == #components
    local error = find_error(component)

    if error then
      return get_error_message(error, state), state
    end

    local next_state = extend(state, {
      first = first,
      last = last,
      parent = state.parent or { type = 'root' }
    })

    local clause = ''
      .. get_prefix(component, options, next_state)
      .. get_infix(component, options, next_state)
      .. get_suffix(component, options, next_state)

    table.insert(clauses, clause)
  end

  local lines = vim.iter(clauses)
    :map(split_lines)
    :flatten()
    :filter(is_non_empty)
    :map(trim_end)
    :totable()

  return lines, state
end

return M
