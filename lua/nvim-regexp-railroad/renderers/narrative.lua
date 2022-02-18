local util = require'nvim-regexp-railroad.util.treesitter'
local descriptions = require'nvim-regexp-railroad.util.descriptions'

local M = {}

local function escape_markdown(str)
  return str:gsub('_', '\\_'):gsub('*', '\\*'):gsub('`', '\\`')
end

local function get_narrative_clause(component, options, first, last)
  local prefix = ''
  local infix = ''
  local suffix = ''

  if first and not last then
    prefix = 'Start with '
  elseif last and not first then
    prefix = 'End with '
  end

  while (util.is_pattern(component) or util.is_term(component)) do
    component = component.children[1]
  end

  if util.is_pattern_character(component) then
    infix = '`' .. escape_markdown(component.text) .. '`'
  end

  if util.is_identity_escape(component) then
    infix = '`' .. component.text:gsub('\\', '', 1) .. '`'
  end

  if util.is_control_escape(component) then
    local char = component.text:gsub('\\', '', 1)
    local desc = descriptions.describe_control_escape(char)
    infix = '`' .. desc .. '`'
  end

  if util.is_boundary_assertion(component) then
    infix = 'a **word boundary**'
  end

  if util.is_character_class(component) then
    infix = escape_markdown(descriptions.describe_character_class(component))
  end

  if util.is_capture_group(component) then
    local depth = (options.depth or 0) + 1

    local sublines = M.get_narrative_lines(component.children, vim.tbl_extend(options, {
      depth = depth,
    }))

    local name = component.group_name and ('`'..component.group_name..'`') or ''

    local sep = '\n '

    for index, line in ipairs(sublines) do
      sublines[index] = (index == #sublines and '' or ' ') .. line
    end
    infix =
        ('capture group ' .. name):gsub(' $', '') .. ':'
      .. sep
      .. table.concat(sublines, sep):gsub(sep .. '$', '')
      .. '\nend capture group' .. name

    if component.type == 'named_capturing_group' then
      vim.notify(vim.inspect(component.children))
      vim.notify(vim.inspect(sublines))
    end

  end

  if component.quantifier then
    local value = component.quantifier.value
    local min = component.quantifier.min
    local max = component.quantifier.max
    if value then
      suffix = ' (_' .. value .. '_ time' .. (value == '1' and '' or 's') .. ')'
    elseif min and max then
      suffix = ' (between _' .. min .. '_ and _' .. max .. '_ times)'
    elseif min then
      suffix = ' (at least _' .. min .. '_ times)'
    end
  end

  if     component.optional then
    suffix = suffix .. '(_optional_)'
  elseif component.zero_or_more then
    suffix = suffix .. ' (_zero or more_ times)'
  elseif component.one_or_more then
    suffix = suffix .. ' (_one or more_ times)'
  end

  return prefix .. infix .. suffix
end

function M.get_narrative_lines(components, options)
  local clauses = {}
  local lines   = {}

  for i, component in ipairs(components) do
    table.insert(clauses, get_narrative_clause(component, options, i == 1, i == #components))
  end

  local narrative = table.concat(clauses, options.separator)

  for line in narrative:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
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
