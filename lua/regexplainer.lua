local ts_utils  = require'nvim-treesitter.ts_utils'
local component = require'regexplainer.component'
local tree      = require'regexplainer.utils.treesitter'
local utils     = require'regexplainer.utils'
local buffers   = require'regexplainer.buffers'

---@class RegexplainerMappings
---@field show?       string      # shows regexplainer
---@field hide?       string      # hides regexplainer
---@field toggle?     string      # toggles regexplainer
---@field show_split? string      # shows regexplainer in a split window
---@field show_popup? string      # shows regexplainer in a popup window

---Maps config.mappings keys to vim command names and descriptions
--
local config_command_map = {
  show       = {'RegexplainerShow',      'Show Regexplainer'},
  hide       = {'RegexplainerHide',      'Hide Regexplainer'},
  toggle     = {'RegexplainerToggle',    'Toggle Regexplainer'},
  showSplit  = {'RegexplainerShowSplit', 'Show Regexplainer in a split Window'},
  showPopup  = {'RegexplainerShowPopup', 'Show Regexplainer in a popup'},
}

---@class RegexplainerOptions
---@field mode             "'narrative'"                        # TODO: 'ascii', 'graphical'
---@field auto             boolean                              # Automatically display when cursor enters a regexp
---@field debug            boolean                              # Notify debug logs
---@field display          "'split'"|"'popup'"                  # Split mode or Popup mode
---@field mappings         RegexplainerMappings                 # keymappings to automatically bind. Supports `which-key`
---@field narrative        RegexplainerNarrativeRendererOptions # Options for the narrative renderer
---@field popup            NuiPopupBufferOptions                # options for the popup buffer
---@field split            NuiSplitBufferOptions                # options for the split buffer
---@field full_regexp_text string                               # **INTERNAL**, do not set.
--
local default_config = {
  mode = 'narrative',
  auto = false,
  debug = false,
  display = 'popup',
  mappings = {
    toggle = 'gR',
  },
  narrative = {
    separator = '\n',
  },
}

--- A deep copy of the default config.
--- During setup(), any user-provided config will be folded in
---@type RegexplainerOptions
--
local local_config = vim.tbl_deep_extend('keep', default_config, {})

--- Show the explainer for the regexp under the cursor
---@param options? RegexplainerOptions overrides for this call
---@return nil
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

    ---@type RegexplainerRenderer
    local renderer
    ---@type boolean, RexeplainerRenderer
    local can_render, _renderer = pcall(require, 'regexplainer.renderers.'.. options.mode)

    if can_render then
      renderer = _renderer
    else
      utils.notify(options.mode .. ' is not a valid renderer', 'warning')
      utils.notify(renderer, 'error')
      renderer = require'regexplainer.renderers.narrative'
    end

    local components = component.make_components(node, nil, node)

    -- Text of the entire regexp
    options.full_regexp_text = ts_utils.get_node_text(node)[1]

    local buffer = buffers.get_buffer(options)

    if not buffer and options.debug then
      utils.notify('' .. options.full_regexp_text .. '\n\nCOMPONENTS:\n' .. vim.inspect(components))
      return
    end

    buffers.render(buffer, renderer, options, components)
  else
    buffers.hide_all()
  end
end

local defer = require'regexplainer.utils.defer'

local debounced_show, timer = defer.debounce_trailing(function(config)
  return show(vim.tbl_deep_extend('keep', config or {}, local_config))
end, 5)

local M = {}

--- Show the explainer for the regexp under the cursor
---@param config RegexplainerOptions)
function M.show(config)
  return debounced_show(config)
end

--- Merge in the user config and setup key bindings
---@param config RegexplainerOptions
---@return nil
--
function M.setup(config)
  local_config = vim.tbl_deep_extend('keep', config or {}, default_config)

  -- bind keys from config
  local has_which_key = pcall(require, 'which-key')
  for cmd, binding in pairs(local_config.mappings) do
    local command = ':' .. config_command_map[cmd][1] .. '<CR>'

    if has_which_key then
      local wk = require'which-key'
      local description = config_command_map[cmd][2]
      wk.register({ [binding] = { command, description } }, { mode = 'n' })
    else
      utils.map('n', binding, command)
    end
  end

  -- setup auto commend if configured
  if local_config.auto then
    vim.cmd [[
      augroup Regexplainer
        au!
        autocmd CursorMoved *.html,*.js,*.ts RegexplainerShow
      augroup END
    ]]
  end
end

--- Hide any displayed regexplainer buffers
--
function M.hide()
  buffers.hide_all()
end

--- Toggle Regexplainer
--
function M.toggle()
  if buffers.is_open() then
    M.hide()
  else
    M.show()
  end
end

return M

