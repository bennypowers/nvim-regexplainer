local ts_utils = require'nvim-treesitter.ts_utils'
local event = require'nui.utils.autocmd'.event
local autocmd = require'nui.utils.autocmd'
local ts_pred = require'nvim-regexp-railroad.util.treesitter'
local descriptions = require'nvim-regexp-railroad.util.descriptions'

local M = {}

-- Using treesitter, find the current node at cursor, and traverse up to the
-- document root to determine if we're on a regexp
--
local function get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  local node = cursor_node

  if cursor_node:type() == 'regex' then
    local iterator = cursor_node:iter_children()
    while node == cursor_node do
      local next = iterator()
      if not next then return end
      vim.notify('next '..next:type())
      local type = next:type()
      if type == 'pattern' then
        node = next
      elseif type == 'regex_pattern' then
        vim.notify('  found regex_pattern')
        vim.notify('  child count '.. next:child_count())
        for child in next:iter_children() do
          vim.notify('  child'..child:type())
          if child:type() == 'pattern' then
            node = child
          end
        end
      end
    end
  end

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

-- Transform a treesitter node to a table of components which are easily rendered
--
local function make_components(node)
  local components = {}

  for child in node:iter_children() do
    local type = child:type()

    if     type == 'optional'               then
      components[#components].optional      = true
    elseif type == 'one_or_more'            then
      components[#components].one_or_more   = true
    elseif type == 'zero_or_more'           then
      components[#components].zero_or_more  = true
    elseif type == 'count_quantifier'       then
      components[#components].quantifier    = descriptions.describe_quantifier(child)
    elseif type ~= 'group_name' and not ts_pred.is_punctuation(type) then
      local component = {
        type = type,
        text = ts_utils.get_node_text(child)[1],
      }

      if ts_pred.is_container(child) then
        if ts_pred.is_named_capturing_group(child) then
          for grandchild in child:iter_children() do
            if ts_pred.is_group_name(grandchild) then
              component.group_name = ts_utils.get_node_text(grandchild)[1]
              break
            end
          end
        end
        component.children = make_components(child)
      end

      table.insert(components, component)
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

    -- in the case of a pattern node, sometimes we need to get the first child  🤷
    if node:child_count() == 1 then
      node = node:child(0)
    end

    local can_render, renderer = pcall(require, 'nvim-regexp-railroad.renderers.'.. options.mode)

    if not can_render then
      vim.notify(options.mode .. ' is not a valid renderer', 'warning')
      renderer = require'nvim-regexp-railroad.renderers.narrative'
    end

    -- this is the `bufnr` where it cursor is currently at (where you're editing your file)
    local parent_bufnr = vim.api.nvim_get_current_buf()
    local components = make_components(node)

    local buffer = get_buffer(options, parent_bufnr)

    if not buffer then
      vim.notify('' .. pattern .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
      return
    end

    buffer:mount()

    local renderer_options = options[options.mode] or {}
    local lines = renderer.set_lines(buffer, components, renderer_options)

    if options.mode == 'popup' then
      buffer:on(event.BufWritePost, function()
        buffer:set_size {
          width = '75%',
          height = #lines,
        }
      end)
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

