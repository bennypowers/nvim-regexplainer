local ts_utils = require'nvim-treesitter.ts_utils'

local M = {}

local function get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  local node = cursor_node

  while node:type() ~= 'pattern' and node:type() ~= 'chunk' do
    local _node = node
    node = ts_utils.get_previous_node(node, true, true) or ts_utils.get_root_for_node(_node)
  end

  if ( not node
    or node == cursor_node
    or node:type() == 'chunk'
  ) then
    return
  end

  local text = ts_utils.get_node_text(node)[1]

  return text, node
end

local function is_container(node)
  local count = node:child_count()
  if count == 0 then
    return false
  else
    local type = node:type()
    return (
      type == 'anonymous_capturing_group' or
      type == 'named_capturing_group'     or
      type == 'pattern'                   or
      type == 'term'                      or
      type == 'character_class'           or
      false
    )
  end
end

local function is_punctuation(type)
  return (
    type == '('   or
    type == ')'   or
    type == '['   or
    type == ']'   or
    type == '(?<' or
    type == '>'   or
    false
  )
end

local function parse_quantifier(quantifier_node)
-- TODO: there's probably a better way to do this
  local text = ts_utils.get_node_text(quantifier_node)[1]
  if text:match',' then
    local matches = {}
    for match in text:gmatch'%d' do
        table.insert(matches, match)
    end
    return {
      min = matches[1],
      max = matches[2],
    }
  else
    return { value = text:match'%d' }
  end
end

local function make_components(node)
  local components = {}

  for child in node:iter_children() do
    local type = child:type()

    if type == 'optional' then
      components[#components].optional = true
    elseif type == 'one_or_more' then
      components[#components].one_or_more = true
    elseif type == 'zero_or_more' then
      components[#components].zero_or_more = true
    elseif type == 'count_quantifier' then
      components[#components].quantifier = parse_quantifier(child)
    elseif not is_punctuation(type) then
      local component = {
        _type = type,
        _text = ts_utils.get_node_text(child)[1],
      }

      if is_container(child) then
        component.children = make_components(child)
      end

      table.insert(components, component)
    end
  end

  return components
end

-- QUESTION: Should maybe use https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/split
M.show_below = function()
  local pattern, regex = get_regexp_pattern_at_cursor()
  if pattern then
    if regex:child_count() == 1 then regex = regex:child(0) end
    local components = make_components(regex)
    vim.notify('' .. pattern .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
  end
end

return M

