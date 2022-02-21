local ts_utils = require'nvim-treesitter.ts_utils'

local M = {}

-- Given a quantifier, return a pretty description like "2 or more times"
--
function M.describe_quantifier(quantifier_node)
  -- TODO: there's probably a better way to do this
  local text = ts_utils.get_node_text(quantifier_node)[1]
  if text:match',' then
    local matches = {}
    for match in text:gmatch'%d' do
        table.insert(matches, match)
    end
    local min = matches[1]
    local max = matches[2]
    if max then
      return min .. '-' .. max .. 'x'
    else
      return '>= ' .. min .. 'x'
    end
  else
    return text:match'%d' .. 'x'
  end

  -- local value = component.quantifier.value
  -- local min = component.quantifier.min
  -- local max = component.quantifier.max
  --
  -- if value then
  --   suffix = ' (_' .. value .. '_ time' .. (value == '1' and '' or 's') .. ')'
  -- elseif min and max then
  --   suffix = ' (between _' .. min .. '_ and _' .. max .. '_ times)'
  -- elseif min then
  --   suffix = ' (at least _' .. min .. '_ times)'
  -- end
end

-- Given `[A-Z0-9._%+_]`, return `'A-Z, 0-9, ., _, %, +, or -'`
--
function M.describe_character_class(component)
  local description = ''
  for i, child in ipairs(component.children) do
    -- TODO: lua equivalent of Intl?
    local oxford = (#component.children > 1 and i == #component.children) and 'or ' or ''
    local initial_sep = i == 1 and '' or ', '

    -- NB: for now we don't consider `class_range` to be a container, but if we change our minds later...
    -- if is_character_class(child) then
    --   description = description .. ', ' .. oxford .. child.text
    -- elseif is_class_range(child) then
    --   local from = child.children[1].text
    --   local to   = child.children[2].text
    --   description = description .. ', ' .. oxford .. from .. '-' .. to
    -- end

    description = description .. initial_sep .. oxford .. child.text
  end
  return description
end

function M.describe_control_escape(char)
  if     char == 'd' then return '0-9'
  elseif char == 'n' then return 'LF'
  elseif char == 'r' then return 'CR'
  elseif char == 's' then return 'WS'
  elseif char == 't' then return 'TAB'
  elseif char == 'w' then return 'WORD'
  else                    return char
  end
end

function M.describe_character(component)
  local type = component.type
  if     type == 'start_assertion' then return 'START'
  elseif type == 'end_assertion'   then return 'END'
  elseif type == 'any_character'   then return 'ANY'
  else                                  return component.text
  end
end

return M

