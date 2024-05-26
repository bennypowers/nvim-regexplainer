local utils         = require 'regexplainer.utils'
local Predicates    = require 'regexplainer.component.predicates'
local get_node_text = vim.treesitter.get_node_text

local M = {}

--- Given a quantifier, return a pretty description like "2 or more times"
---@param quantifier_node TreesitterNode
---@return string
--
function M.describe_quantifier(quantifier_node, bufnr)
  -- TODO: there's probably a better way to do this
  local text = get_node_text(quantifier_node, bufnr)
  if text:match ',' then
    local matches = {}
    for match in text:gmatch '%d+' do
      table.insert(matches, match)
    end
    local min, max = unpack(matches)
    if max then
      return min .. '-' .. max .. 'x'
    else
      return '>= ' .. min .. 'x'
    end
  else
    local match = text:match '%d+'
    return match .. 'x'
  end
end

--- Given `[A-Z0-9._%+_]`, return `'A-Z, 0-9, ., _, %, +, or -'`
---@param component RegexplainerComponent
---@return string
--
function M.describe_character_class(component)
  local description = (component.negative and 'Any except ' or 'One of ')
  for i, child in ipairs(component.children) do
    -- TODO: lua equivalent of Intl?
    local oxford = (#(component.children) > 1 and i == #(component.children)) and 'or ' or ''
    local initial_sep = i == 1 and '' or ', '
    local text = utils.escape_markdown(child.text)

    if Predicates.is_identity_escape(child) then
      text = '`' .. text:sub(-1) .. '`'
    elseif Predicates.is_escape(child) then
      text = '**' .. M.describe_escape(text) .. '**'
    else
      text = '`' .. text .. '`'
    end

    description = description .. initial_sep .. oxford .. text
  end
  return description
end

---@param escape string
---@return string
function M.describe_escape(escape)
  local char = escape:gsub([[\\]], [[\]]):sub(2)
      if char == 'd' then return '0-9'
  elseif char == 'n' then return 'LF'
  elseif char == 'r' then return 'CR'
  elseif char == 's' then return 'WS'
  elseif char == 'b' then return 'WB'
  elseif char == 't' then return 'TAB'
  elseif char == 'w' then return 'WORD'
  else return char
  end
end

---@param component RegexplainerComponent
---@return string
function M.describe_character(component)
  local type = component.type
  if type == 'start_assertion' then return 'START'
  elseif type == 'end_assertion' then return 'END'
  elseif type == 'any_character' then return 'ANY'
  else return component.text
  end
end

return M
