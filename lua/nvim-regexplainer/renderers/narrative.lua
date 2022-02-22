local descriptions           = require'nvim-regexplainer.util.descriptions'
local component_pred         = require'nvim-regexplainer.util.component'
local utils                  = require'nvim-regexplainer.util.utils'

-- A textual, narrative renderer which describes a regexp in terse prose
--
local M = {}

-- get a suffix describing the component's quantifier, optionality, etc
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

local function get_group_heading(component)
  local name = component.group_name and ('`'..component.group_name..'`') or ''

  return (component.type == 'named_capturing_group' and 'named capture group ' .. component.capture_group .. ' ' .. name
       or component.type == 'non_capturing_group' and 'non-capturing group '
       or 'capture group '.. component.capture_group):gsub(' $', '')
end

local function get_sublines(component, options)
  local depth = (options.depth or 0) + 1
  local sep = '\n' for _ = 0, depth do sep = sep .. ' ' end

  if type(options.separator) == "function" then
    sep = options.separator(component)
  end

  local children = component.children
  while (#children == 1 and (component_pred.is_term(children[1])
                             or component_pred.is_pattern(children[1]))) do
    children = children[1].children
  end

  local next_options = vim.tbl_extend('keep', options, { depth = depth })

  return M.get_lines(children, next_options), sep

end

local function get_narrative_clause(component, options, first, last)
  local prefix = ''
  local infix = ''
  local suffix = ''

  if first and not last then
    prefix = ''
  elseif not options.depth and last and not first then
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
              .. get_narrative_clause(child,
                                      options,
                                      first_in_alt,
                                      last_in_alt)
    end
  end

  if component_pred.is_term(component) and component_pred.is_only_chars(component) then
    infix = '`' .. component.text .. '`'
  else
    while (component_pred.is_pattern(component) or component_pred.is_term(component)) do
      component = component.children[1]
    end
  end

  if component_pred.is_pattern_character(component) then
    infix = '`' .. utils.escape_markdown(component.text) .. '`'
  end

  if component_pred.is_identity_escape(component) then
    infix = '`' .. component.text:sub(2) .. '`'
  elseif component_pred.is_special_character(component) then
    infix = '**' .. utils.escape_markdown(descriptions.describe_character(component)) .. '**'
  elseif component_pred.is_control_escape(component) then
    local char = component.text:sub(2)
    local desc = descriptions.describe_control_escape(char) or char
    infix = '**' .. desc .. '**'
  end

  if component_pred.is_lookahead_assertion(component) then
    local negation = component.negative and 'NOT ' or ''
    prefix = '**' .. negation .. 'followed by' .. '**'

    local sublines, sep = get_sublines(component, options)
    local contents = table.concat(sublines, sep):gsub(sep .. '$', '')

    infix =
         get_suffix(component)
      .. ':'
      .. sep
      .. contents
      .. '\n'
  end

  if component_pred.is_boundary_assertion(component) then
    infix = '**WB**'
  end

  if component_pred.is_character_class(component) then
    infix = descriptions.describe_character_class(component)
  end

  if component_pred.is_capture_group(component) then
    local sublines, sep = get_sublines(component, options)
    local contents = table.concat(sublines, sep):gsub(sep .. '$', '')

    infix =
         get_group_heading(component)
      .. get_suffix(component)
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

function M.get_lines(components, options)
  local clauses = {}
  local lines   = {}

  for i, component in ipairs(components) do
    local first = i == 1
    local last = i == #components
    if component.type == 'ERROR' then
      lines[1] = '🚨 **Regexp contains an ERROR** at'
      lines[2] = components[i + 1].text
      lines[3] = ''
      for _ = 1, component.error.position[1][2] - component.error.start_offset do
        lines[3] = lines[3] .. ' '
      end
      lines[3] = lines[3] .. '👆'
      return lines
    end
    local next_clause = get_narrative_clause(component,
                                             options,
                                             first,
                                             last)
    if component_pred.is_lookahead_assertion(component) then
      clauses[#clauses] = clauses[#clauses] .. ' ' .. next_clause
    else
      table.insert(clauses, next_clause)
    end
  end

  local separator = options.separator
  if type(separator) == "function" then
    separator = separator({ type = 'root', depth = 0 })
  end

  local narrative = table.concat(clauses, separator)

  for line in narrative:gmatch("([^\n]*)\n?") do
    if #line > 0 then
      table.insert(lines, (line:gsub('^ +End', 'End')))
    end
  end

  return lines
end

function M.set_lines(buf, lines)
  vim.api.nvim_win_call(buf.winid, function()
    vim.lsp.util.stylize_markdown(buf.bufnr, lines)
  end)
  return lines
end

return M
