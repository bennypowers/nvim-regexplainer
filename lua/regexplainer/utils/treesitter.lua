local M = {}

local GUARD_MAX = 1000

local get_node_text = vim.treesitter.get_node_text or vim.treesitter.query.get_node_text

local node_types = {
  'alternation',
  'boundary_assertion',
  'character_class',
  'character_class_escape',
  'chunk',
  'class_range',
  'count_quantifier',
  'document',
  'group_name',
  'identity_escape',
  'lookaround_assertion',
  'named_capturing_group',
  'non_capturing_group',
  'one_or_more',
  'optional',
  'pattern',
  'pattern_character',
  'program',
  'source',
  'term',
  'zero_or_more',
}

for _, type in ipairs(node_types) do
  ---@type fun(node: TSNode): boolean
  M['is_' .. type] = function(node)
    if not node then
      return false
    end
    return node and node:type() == type
  end
end

-- Get previous node with same parent
---@param node?                  TSNode
---@param allow_switch_parents?  boolean allow switching parents if first node
---@param allow_previous_parent? boolean allow previous parent if first node and previous parent without children
---@return TSNode?
local function get_previous_node(node, allow_switch_parents, allow_previous_parent)
  local destination_node ---@type TSNode?
  local parent = node and node:parent()
  if not parent then
    return
  end

  local found_pos = 0
  for i = 0, parent:named_child_count() - 1, 1 do
    if parent:named_child(i) == node then
      found_pos = i
      break
    end
  end
  if 0 < found_pos then
    destination_node = parent:named_child(found_pos - 1)
  elseif allow_switch_parents then
    local previous_node = get_previous_node(parent)
    if previous_node and previous_node:named_child_count() > 0 then
      destination_node = previous_node:named_child(previous_node:named_child_count() - 1)
    elseif previous_node and allow_previous_parent then
      destination_node = previous_node
    end
  end
  return destination_node
end

---@param node? TSNode
---@return TSNode?
local function get_root_for_node(node)
  ---@type TSNode?
  local parent = node
  local result = node

  while parent ~= nil do
    result = parent
    parent = result:parent()
  end

  return result
end

---@param row number
---@param col number
---@param root_lang_tree vim.treesitter.LanguageTree
---@return TSNode?
local function get_root_for_position(row, col, root_lang_tree)
  local lang_tree = root_lang_tree:language_for_range { row, col, row, col }

  for _, tree in pairs(lang_tree:trees()) do
    local root = tree:root()

    if root and vim.treesitter.is_in_node_range(root, row, col) then
      return root
    end
  end

  return nil
end

---@param root_lang_tree vim.treesitter.LanguageTree
---@return TSNode?
local function get_node_at_cursor(root_lang_tree)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_range = { cursor[1] - 1, cursor[2] }

  ---@type TSNode?
  local root = get_root_for_position(cursor_range[1], cursor_range[2], root_lang_tree)

  if not root then
    return
  end

  return root:named_descendant_for_range(cursor_range[1], cursor_range[2], cursor_range[1], cursor_range[2])
end

---Enter a parent-language's regexp node which contains the embedded
---regexp grammar
---@param root_lang_tree vim.treesitter.LanguageTree
---@param node TSNode
---@return TSNode?
local function enter_js_re_node(root_lang_tree, node)
  -- cribbed from get_node_at_cursor impl
  local row, col = vim.treesitter.get_node_range(node)

  local root = get_root_for_position(row, col + 1--[[hack that works for js]], root_lang_tree)

  if not root then
    root = get_root_for_node(node)

    if not root then
      return nil
    end
  end

  return root:named_descendant_for_range(row, col + 1, row, col + 1)
end

---Containers are regexp treesitter nodes which may contain leaf nodes like pattern_character.
---An example container is anonymous_capturing_group.
--
---@param node TSNode regexp treesitter node
---@return boolean
function M.is_container(node)
  if node:child_count() == 0 then
    return false
  else
    local type = node:type()
    return type == 'anonymous_capturing_group'
        or type == 'alternation'
        or type == 'character_class'
        or type == 'lookaround_assertion'
        or type == 'named_capturing_group'
        or type == 'non_capturing_group'
        or type == 'pattern'
        or type == 'term'
        or false
  end
end

-- For reasons the author has yet to understand, punctuation like the opening of
-- a named_capturing_group gets registered as components when traversing the tree. Let's exclude them.
--
function M.is_punctuation(type)
  return type == '^'
      or type == '('
      or type == ')'
      or type == '['
      or type == ']'
      or type == '!'
      or type == '='
      or type == '>'
      or type == '|'
      or type == '(?<'
      or type == '(?:'
      or type == '(?'
      or false
end

-- Is this the document root (or close enough for our purposes)?
---@param node? TSNode
---@return boolean
function M.is_document(node)
  if node == nil then return true else
    local type = node:type()
    return type == 'program'
        or type == 'document'
        or type == 'source'
        or type == 'source_file'
        or type == 'fragment'
        or type == 'chunk'
        -- if we're in an embedded language
        or type == 'stylesheet'
        or type == 'haskell'
        -- Wha happun?
        or type == 'ERROR' and not (M.is_pattern(node:parent()) or M.is_term(node:parent()))
  end
end

---@param node TSNode
---@return unknown
function M.is_control_escape(node)
  return require 'regexplainer.component'.is_control_escape {
    type = node:type(),
    text = get_node_text(node, 0),
  }
end

-- Should we stop here when traversing upwards through the tree from the cursor node?
--
function M.is_upwards_stop(node)
  return node and node:type() == 'pattern' or M.is_document(node)
end

-- Is it a lookaround assertion?
function M.is_lookaround_assertion(node)
  return require 'regexplainer.component'.is_lookaround_assertion { type = node:type() }
end

function M.is_modifier(node)
  return M.is_optional(node)
      or M.is_one_or_more(node)
      or M.is_zero_or_more(node)
      or M.is_count_quantifier(node)
end

--- Using treesitter, find the current node at cursor, and traverse up to the
--- document root to determine if we're on a regexp
---@param options RegexplainerOptions
---@return any, string|nil
--
function M.get_regexp_pattern_at_cursor(options)
  local filetype = vim.bo[0].ft
  if not vim.tbl_contains(options.filetypes, filetype) then
    return nil, 'unrecognized filetype'
  end
  local root_lang_tree = vim.treesitter.get_parser(0, vim.treesitter.language.get_lang(filetype))
  local cursor_node = get_node_at_cursor(root_lang_tree)
  local cursor_node_type = cursor_node and cursor_node:type()
  if not cursor_node or cursor_node_type == 'program' then
    return
  end

  ---@type TSNode?
  local node = cursor_node

  if node and node:type() == 'regex' then
    local iterator = node:iter_children()

    -- break if we enter an infinite loop (probably)
    --
    local guard = 0
    while node == cursor_node do
      guard = guard + 1
      if guard >= GUARD_MAX then
        return nil, 'loop exceeded ' .. GUARD_MAX .. ' at node ' .. (node and node:type() or 'nil')
      end

      local next = iterator()

      if not next then
        return nil, 'no downwards node'
      else
        local type = next:type()

        if type == 'pattern' then
          node = next
        elseif type == 'regex_pattern' or type == 'regex' then
          node = enter_js_re_node(root_lang_tree, next)
          if not node then
            return nil, 'no node immediately to the right of the regexp node'
          end
        end
      end
    end
  end

  -- break if we enter an infinite loop (probably)
  --
  local guard = 0
  while not M.is_upwards_stop(node) do
    guard = guard + 1
    if guard >= GUARD_MAX then
      return nil, 'loop exceeded ' .. GUARD_MAX .. ' at node ' .. (node and node:type() or 'nil')
    end

    local _node = node
    node = get_previous_node(node, true, true)
    if not node then
      node = get_root_for_node(_node)
      if not node then
        return nil, 'no upwards node'
      end
    end
  end

  if M.is_document(node) then
    return nil, nil
  elseif node == cursor_node then
    return nil, 'stuck on cursor_node'
  elseif not node then
    return nil, 'unexpected no downwards node'
  end

  return node, nil
end

return M
