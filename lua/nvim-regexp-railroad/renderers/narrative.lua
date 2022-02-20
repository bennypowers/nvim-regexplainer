local descriptions = require'nvim-regexp-railroad.util.descriptions'
local util = require'nvim-regexp-railroad.util.treesitter'

local M = {}

local function escape_markdown(str)
  return str:gsub('_', '\\_'):gsub('*', '\\*'):gsub('`', '\\`')
end

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

local function get_narrative_clause(component, options, first, last)
  local prefix = ''
  local infix = ''
  local suffix = ''

  if first and not last then
    prefix = options.is_alternation and '' or ''
  elseif not options.depth and last and not first then
    prefix = options.is_alternation and '' or ''
  end

  if util.is_alternation(component) then
    for i, child in ipairs(component.children) do
      local oxford = i == #component.children and 'or ' or ''
      local first_in_alt = i == 1
      local last_in_alt = i == #component.children
      prefix = 'Either '
      infix = infix
              .. (first_in_alt and '' or #component.children == 2 and ' ' or ', ')
              .. oxford
              .. get_narrative_clause(child,
                                      vim.tbl_extend('keep', options, { is_alternation = true }),
                                      first_in_alt,
                                      last_in_alt)
    end
  end

  if util.is_term(component) and util.is_only_chars(component) then
    infix = '`' .. component.text .. '`'
  else
    while (util.is_pattern(component) or util.is_term(component)) do
      component = component.children[1]
    end
  end

  if util.is_pattern_character(component) then
    infix = '`' .. escape_markdown(component.text) .. '`'
  end

  if util.is_identity_escape(component) then
    infix = '`' .. component.text:gsub('\\', '', 1) .. '`'
  end

  if util.is_control_escape(component) then
    local char = component.text:gsub('\\', '', 1)
    local desc = descriptions.describe_control_escape(char) or char
    infix = '**' .. desc .. '**'
  end

  if util.is_boundary_assertion(component) then
    infix = '**WB**'
  end

  if util.is_character_class(component) then
    infix = escape_markdown(descriptions.describe_character_class(component))
  end

  if util.is_capture_group(component) then
    local depth = (options.depth or 0) + 1
    local sep = '\n' for _ = 0, depth do sep = sep .. ' ' end

    local children = component.children
    while (#children == 1 and (util.is_term(children[1])
                               or util.is_pattern(children[1]))) do
      children = children[1].children
    end

    local sublines = M.get_narrative_lines(children,
                                           vim.tbl_extend('keep', options, {
                                             depth = depth,
                                           }))

    -- for index, line in ipairs(sublines) do
    --   sublines[index] = (index == #sublines and '' or '') .. line
    -- end

    local contents = table.concat(sublines, sep):gsub(sep .. '$', '')

    infix =
         get_group_heading(component)
      .. get_suffix(component)
      .. ':'
      .. sep
      .. contents
      .. '\n'
  else
    suffix = get_suffix(component)
  end

  return prefix .. infix .. suffix
end

function M.get_narrative_lines(components, options)
  local clauses = {}
  local lines   = {}

  for i, component in ipairs(components) do
    local first = i == 1
    local last = i == #components
    table.insert(clauses, get_narrative_clause(component,
                                               options,
                                               first,
                                               last))
  end

  local narrative = table.concat(clauses, options.separator)

  for line in narrative:gmatch("([^\n]*)\n?") do
    if #line > 0 then
      table.insert(lines, (line:gsub('^ +End', 'End')))
    end
  end

  return lines
end

function M.set_lines(buf, components, options)
  local lines = M.get_narrative_lines(components, options)
  vim.api.nvim_buf_call(buf.bufnr, function()
    vim.lsp.util.stylize_markdown(buf.bufnr, lines)
  end)
  return lines
end

return M
