local ts_utils  = require'nvim-treesitter.ts_utils'
local component = require'regexplainer.component'
local tree      = require'regexplainer.utils.treesitter'
local utils     = require'regexplainer.utils'
local buffers   = require'regexplainer.buffers'

local M = {}

local config_command_map = {
  show = 'RegexplainerShow',
}

local config_command_description_map = {
  show = 'Explain the regexp under the cursor',
}

local default_config = {
  -- 'narrative'
  mode = 'narrative', -- TODO: 'ascii', 'graphical'

  -- automatically show the explainer when the cursor enters a regexp
  auto = false,

  -- Whether to log debug messages
  debug = false,

  -- 'split', 'popup'
  display = 'popup',

  mappings = {
    show = 'gR',
  },

  narrative = {
    separator = '\n',
  },
}

local local_config = default_config

-- Show the explainer for the regexp under the cursor
--
local function show(options)
  local node, error = tree.get_regexp_pattern_at_cursor()

  if error and options.debug then
    utils.notify('Rexexplainer: ' .. error, 'debug')
  elseif node then
    -- in the case of a pattern node, we need to get the first child  🤷
    if node:type() == 'pattern' and node:child_count() == 1 then
      node = node:child(0)
    end

    local can_render, renderer = pcall(require, 'regexplainer.renderers.'.. options.mode)

    if not can_render then
      utils.notify(options.mode .. ' is not a valid renderer', 'warning')
      utils.notify(renderer, 'error')

      renderer = require'regexplainer.renderers.narrative'
    end

    local components = component.make_components(node, nil, node)

    -- Text of the entire regexp
    options.full_regexp_text = ts_utils.get_node_text(node)[1]

    local buffer = buffers.get_buffer(options)

    if not buffer then
      utils.notify('' .. options.full_regexp_text .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
      return
    end

    buffers.render(buffer, renderer, options, components)
  else
    buffers.hide_all()
  end
end

local debounced_show = require'regexplainer.utils.defer'.debounce_trailing(function(config)
  return show(vim.tbl_deep_extend('keep', config or {}, local_config))
end, 5)

-- merge in the user config and setup key bindings
M.setup = function(config)
  local_config = vim.tbl_deep_extend('keep', config or {}, default_config)

  -- bind keys from config
  local has_which_key, wk = pcall(require, 'which-key')
  for cmd, binding in pairs(local_config.mappings) do
    local command = ':' .. config_command_map[cmd] .. '<CR>'

    if has_which_key then
      local description = config_command_description_map[cmd]
      wk.register({ [binding] = { command, description } }, { mode = 'n' })
    else
      utils.map('n', binding, command)
    end
  end

  -- setup auto commend if configured
  if local_config.auto then
    vim.cmd [[
      augroup Regexplainer
        autocmd CursorMoved *.html,*.js,*.ts RegexplainerShow
      augroup END
    ]]
  end
end

-- Explain the regexp under the cursor
--
M.show = debounced_show

-- Hide any displayed regexplainer buffers
--
M.hide = function()
  buffers.hide_all()
end

return M
