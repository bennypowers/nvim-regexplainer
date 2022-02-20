local ts_utils = require'nvim-treesitter.ts_utils'
local event = require'nui.utils.autocmd'.event
local autocmd = require'nui.utils.autocmd'
local ts_pred = require'nvim-regexp-railroad.util.treesitter'
local descriptions = require'nvim-regexp-railroad.util.descriptions'
local utils = require'nvim-regexp-railroad.util.utils'

local M = {}

-- Using treesitter, find the current node at cursor, and traverse up to the
-- document root to determine if we're on a regexp
--
local function get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  if cursor_node:type() == 'program' then return end

  local node = cursor_node

  if node:type() == 'regex' then
    local iterator = node:iter_children()
    while node == cursor_node do
      local next = iterator()

      if not next then return end

      local type = next:type()
      if type == 'pattern' then
        node = next
      elseif type == 'regex_pattern' or type == 'regex' then
        -- cribbed from get_node_at_cursor impl
        local parsers = require "nvim-treesitter.parsers"
        local root_lang_tree = parsers.get_parser(0)
        local row, col = ts_utils.get_node_range(next)

        local root = ts_utils.get_root_for_position(row, col + 1 --[[hack that works for js]], root_lang_tree)

        if not root then
          return
        end

        node = root:named_descendant_for_range(row, col + 1, row, col + 1)
      end
    end
  end

  while node:type() ~= 'pattern' do
    local _node = node
    node = ts_utils.get_previous_node(node, true, true)
    if not node then
      node = ts_utils.get_root_for_node(_node)
    end
  end

  if ( not node
    or node == cursor_node
    or node:type() == 'chunk'
    or node:type() == 'program'
  ) then
    return
  end

  local text = ts_utils.get_node_text(node)[1]

  return text, node
end

-- keep track of how many captures we've seen
-- make sure to unset when finished a regexp
--
local capture_tally = 0
local root_regex_node

-- Transform a treesitter node to a table of components which are easily rendered
--
local function make_components(node)
  local components = {}

  local node_type = node:type()

  -- if node:type() == 'alternation' then
  --   local children = {}
  --   for child in node:iter_children() do
  --     local child_components = make_components(child)
  --     for _, child_component in ipairs(child_components) do
  --       table.insert(children, child_component)
  --     end
  --   end
  --   table.insert(components, {
  --     type = 'alternation',
  --     text = ts_utils.get_node_text(node)[1],
  --     children = children
  --   })
  -- else
  -- end

  if node_type == 'alternation' and node == root_regex_node then
    table.insert(components, {
      type = node_type,
      text = ts_utils.get_node_text(node)[1],
      children = {},
    })
  end

  for child in node:iter_children() do
    local type = child:type()

    if type == 'optional'         then
      components[#components].optional      = true
    elseif type == 'one_or_more'      then
      components[#components].one_or_more   = true
    elseif type == 'zero_or_more'     then
      components[#components].zero_or_more  = true
    elseif type == 'count_quantifier' then
      components[#components].quantifier    = descriptions.describe_quantifier(child)
    elseif type == 'pattern_character' and ts_pred.is_simple_pattern_character(components[#components]) then
      components[#components].text = components[#components].text .. ts_utils.get_node_text(child)[1]
    elseif type == 'alternation' then
      table.insert(components, {
        type = type,
        text = ts_utils.get_node_text(child)[1],
        children = make_components(child)
      })
    elseif type ~= 'group_name' and not ts_pred.is_punctuation(type) then
      local component = {
        type = type,
        text = ts_utils.get_node_text(child)[1],
      }

      if ts_pred.is_container(child) then
        if type == 'named_capturing_group' or type == 'anonymous_capturing_group' then
          capture_tally = capture_tally + 1
          component.capture_group = capture_tally
        end
        if ts_pred.is_named_capturing_group(child) then
          -- find the group_name
          for grandchild in child:iter_children() do
            if ts_pred.is_group_name(grandchild) then
              component.group_name = ts_utils.get_node_text(grandchild)[1]
              break
            end
          end
        end

        component.children = make_components(child)
      end

      local target = components
      if node == root_regex_node and root_regex_node:type() == 'alternation' then
        target = components[#components].children
      end
      table.insert(target, component)
    end
  end

  return components
end

-- Get the buffer in which to render the explainer
--
local function get_buffer(options, parent_bufnr)
  if options.display == 'split' then
    return require'nui.split' {
      relative = 'editor',
      position = 'bottom',
      enter = false,
      focusable = false,
      size = '20%',
      buf_options = {
        readonly = true,
        modifiable = false,
      },
      win_options = {
        wrap = true,
        conceallevel = 2,
      },
    }
  elseif options.display == 'popup' then
    local buffer = require'nui.popup' {
      position = 1,
      relative = 'cursor',
      enter = false,
      focusable = false,
      size = {
        width = '75%',
        height = 5,
      },
      border = {
        padding = { 1, 2 },
        style = 'shadow',
      },
      buf_options = {
        readonly = false,
        modifiable = true,
      },
      win_options = {
        wrap = true,
        conceallevel = 3,
      },
    }

    autocmd.buf.define(parent_bufnr, event.CursorMoved, function()
      buffer:unmount()
    end, { once = true })

    return buffer
  end
end

-- Show the explainer for the regexp under the cursor
--
function M.show(options)
  local pattern, node = get_regexp_pattern_at_cursor()
  if pattern then

    -- in the case of a pattern node, we need to get the first child  🤷
    if node:type() == 'pattern' and node:child_count() == 1 then
      node = node:child(0)
    end

    local can_render, renderer = pcall(require, 'nvim-regexp-railroad.renderers.'.. options.mode)

    if not can_render then
      vim.notify(options.mode .. ' is not a valid renderer', 'warning')
      renderer = require'nvim-regexp-railroad.renderers.narrative'
    end

    -- this is the `bufnr` where it cursor is currently at (where you're editing your file)
    local parent_bufnr = vim.api.nvim_get_current_buf()
    root_regex_node = node
    local components = make_components(node)
    capture_tally = 0

    local buffer = get_buffer(options, parent_bufnr)

    if not buffer then
      vim.notify('' .. pattern .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
      return
    end

    buffer:mount()

    local renderer_options = options[options.mode] or {}
    local lines = renderer.set_lines(buffer, components, renderer_options)

    if options.display == 'popup' then
      buffer:set_size {
        width = '75%',
        height = #lines,
      }
    end

    vim.api.nvim_buf_call(parent_bufnr, function()
     vim.api.nvim_set_current_buf(parent_bufnr)
      buffer:on({ event.BufLeave, event.BufWinLeave }, function ()
        vim.schedule(function()
          buffer:unmount()
        end)
      end, { once = true })

    end)
  end
end

return M

