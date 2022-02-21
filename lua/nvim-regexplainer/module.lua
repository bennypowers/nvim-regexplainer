local ts_utils            = require'nvim-treesitter.ts_utils'
local component           = require'nvim-regexplainer.util.component'
local tree                = require'nvim-regexplainer.util.treesitter'
local utils               = require'nvim-regexplainer.util.utils'
local buffers             = require'nvim-regexplainer.util.buffers'

local M = {}

-- Using treesitter, find the current node at cursor, and traverse up to the
-- document root to determine if we're on a regexp
--
local function get_regexp_pattern_at_cursor()
  local cursor_node = ts_utils.get_node_at_cursor()
  if not cursor_node or cursor_node:type() == 'program' then return end

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

  while not tree.is_upwards_stop(node) do
    local _node = node
    node = ts_utils.get_previous_node(node, true, true)
    if not node then
      node = ts_utils.get_root_for_node(_node)
    end
  end

  if node == cursor_node or tree.is_document(node) then
    return
  end

  return node
end

-- Show the explainer for the regexp under the cursor
--
local function show(options)
  local node = get_regexp_pattern_at_cursor()
  if node then

    -- in the case of a pattern node, we need to get the first child  🤷
    if node:type() == 'pattern' and node:child_count() == 1 then
      node = node:child(0)
    end

    local can_render, renderer = pcall(require, 'nvim-regexplainer.renderers.'.. options.mode)

    if not can_render then
      utils.notify(options.mode .. ' is not a valid renderer', 'warning')
      utils.notify(renderer, 'error')

      renderer = require'nvim-regexplainer.renderers.narrative'
    end

    local components = component.make_components(node, nil, node)

    local text = ts_utils.get_node_text(node)[1]

    local buffer = buffers.get_buffer(options, {
      parent = {
        winnr = vim.api.nvim_get_current_win(),
        bufnr = vim.api.nvim_get_current_buf(),
      }
    })

    if not buffer then
      utils.notify('' .. text .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
      return
    end

    local renderer_options = options[options.mode] or {}

    buffers.render(buffer, renderer, renderer_options, components)
  else
    M.hide(options)
  end
end

function M.hide(options)
  if not options.display == 'split' then return end
  local buffer = buffers.get_buffer(options, {
    parent = {
      winnr = vim.api.nvim_get_current_win(),
      bufnr = vim.api.nvim_get_current_buf(),
    }
  })
  buffer:hide()
end

M.show = require'nvim-regexplainer.util.defer'.debounce_trailing(show, 50, true)

return M

