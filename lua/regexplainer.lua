local component = require 'regexplainer.component'
local tree      = require 'regexplainer.utils.treesitter'
local utils     = require 'regexplainer.utils'
local Buffers   = require 'regexplainer.buffers'

local get_node_text = vim.treesitter.get_node_text
local deep_extend = vim.tbl_deep_extend
local map = vim.tbl_map
local buf_delete = vim.api.nvim_buf_delete
local ag = vim.api.nvim_create_augroup
local au = vim.api.nvim_create_autocmd

---@class RegexplainerOptions
---@field mode?             'narrative'|'debug'|'graphical'      # Renderer mode
---@field auto?             boolean                              # Automatically display when cursor enters a regexp
---@field filetypes?        string[]                             # Filetypes (extensions) to automatically show regexplainer.
---@field debug?            boolean                              # Notify debug logs
---@field display?          'split'|'popup'
---@field mappings?         RegexplainerMappings                 # keymappings to automatically bind.
---@field narrative?        RegexplainerNarrativeRendererOptions # Options for the narrative renderer
---@field graphical?        RegexplainerGraphicalRendererOptions # Options for the graphical renderer
---@field deps?             RegexplainerDepsConfig               # Options for dependency management
---@field popup?            NuiPopupBufferOptions                # options for the popup buffer
---@field split?            NuiSplitBufferOptions                # options for the split buffer

---@class RegexplainerRenderOptions: RegexplainerOptions
---@field register          "*"|"+"|'"'|":"|"."|"%"|"/"|"#"|"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"

---@class RegexplainerYankOptions: RegexplainerOptions
---@field register          "*"|"+"|'"'|":"|"."|"%"|"/"|"#"|"0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"

---@class RegexplainerMappings
---@field show?       string      # shows regexplainer
---@field hide?       string      # hides regexplainer
---@field toggle?     string      # toggles regexplainer
---@field yank?       string      # yanks regexplainer
---@field show_split? string      # shows regexplainer in a split window
---@field show_popup? string      # shows regexplainer in a popup window

---Maps config.mappings keys to vim command names and descriptions
--
local config_command_map = {
  show       = { 'RegexplainerShow', 'Show Regexplainer' },
  hide       = { 'RegexplainerHide', 'Hide Regexplainer' },
  toggle     = { 'RegexplainerToggle', 'Toggle Regexplainer' }, yank       = { 'RegexplainerYank', 'Yank Regexplainer' },
  show_split = { 'RegexplainerShowSplit', 'Show Regexplainer in a split Window' },
  show_popup = { 'RegexplainerShowPopup', 'Show Regexplainer in a popup' },
}

---Augroup for auto = true
local augroup_name = 'Regexplainer'

---@type RegexplainerOptions
local default_config = {
  mode = 'narrative',
  auto = false,
  filetypes = {
    'html',
    'js', 'javascript', 'cjs', 'mjs',
    'ts', 'typescript', 'cts', 'mts',
    'tsx', 'typescriptreact', 'ctsx', 'mtsx',
    'jsx', 'javascriptreact', 'cjsx', 'mjsx',
  },
  debug = false,
  display = 'popup',
  mappings = {
    toggle = 'gR',
  },
  narrative = {
    indentation_string = '  ',
  },
  graphical = {
    width = 800,
    height = 600,
    python_cmd = nil, -- Will be auto-detected
  },
  deps = {
    auto_install = true,
    python_cmd = nil, -- Will be auto-detected
    venv_path = nil,  -- Will be auto-generated
    check_interval = 3600,
  },
}

--- A deep copy of the default config.
--- During setup(), any user-provided config will be folded in
---@type RegexplainerOptions
--
local local_config = deep_extend('keep', default_config, {})

--- Show the explainer for the regexp under the cursor
---@param options? RegexplainerOptions overrides for this call
---@return nil|number bufnr the bufnr of the regexplaination
--
local function show_for_real(options)
  options = deep_extend('force', local_config, options or {})
  local node, scratchnr, error = tree.get_regexp_pattern_at_cursor()

  if error and options.debug then
    utils.notify('Rexexplainer: ' .. error, 'debug')
  elseif node and scratchnr then
    ---@type boolean, RegexplainerRenderer
    local can_render, renderer = pcall(require, 'regexplainer.renderers.' .. options.mode)

    if not can_render then
      utils.notify(options.mode .. ' is not a valid renderer', 'warning')
      utils.notify(renderer, 'error')
      renderer = require 'regexplainer.renderers.narrative'
    end

    local components = component.make_components(scratchnr, node, nil, node)

    local buffer = Buffers.get_buffer(options)

    if not buffer and options.debug then
      renderer = require'regexplainer.renderers.debug'
    end

    local start_row, start_col, end_row, end_col = node:range()
    local state = { 
      full_regexp_text = get_node_text(node, scratchnr),
      full_regexp_range = {
        start = { row = start_row, column = start_col },
        finish = { row = end_row, column = end_col }
      }
    }

    Buffers.render(buffer, renderer, components, options, state)
    buf_delete(scratchnr, { force = true })
  else
    Buffers.hide_all()
  end
end

local disable_auto = false

local M = {}

--- Show the explainer for the regexp under the cursor
---@param options? RegexplainerOptions
function M.show(options)
  disable_auto = true
  show_for_real(options)
  disable_auto = false
end

--- Yank the explainer for the regexp under the cursor into a given register
---@param options? string|RegexplainerYankOptions
function M.yank(options)
  disable_auto = true
  if type(options) == 'string' then
    options = { register = options }
  end
  show_for_real(deep_extend('force', options, { display = 'register' }))
  disable_auto = false
end

--- Merge in the user config and setup key bindings
---@param config? RegexplainerOptions
---@return nil
--
function M.setup(config)
  local_config = deep_extend('keep', config or {}, default_config)

  -- bind keys from config
  for cmdmap, binding in pairs(local_config.mappings) do
    local cmd, description = unpack(config_command_map[cmdmap])
    local command = ':' .. cmd .. '<CR>'
    utils.map('n', binding, command, { desc = description })
  end

  -- setup autocommand
  if local_config.auto then
    ag(augroup_name, { clear = true })
    au('CursorMoved', {
      group = 'Regexplainer',
      pattern = map(function(x) return '*.' .. x end, local_config.filetypes),
      callback = function()
        if tree.has_regexp_at_cursor() and not disable_auto then
          show_for_real()
        end
      end,
    })
  else
    pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
  end
end

--- Hide any displayed regexplainer buffers
--
function M.hide()
  Buffers.hide_all()
end

--- Toggle Regexplainer
--
function M.toggle()
  if Buffers.is_open() then
    M.hide()
  else
    M.show()
  end
end

--- **INTERNAL** for testing only
--
function M.teardown()
  local_config = vim.tbl_deep_extend('keep', {}, default_config)
  Buffers.clear_timers()
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

--- **INTERNAL** notify the component tree for the current regexp
--
function M.debug_components()
  ---@type any
  local mode = 'debug'
  show_for_real({ auto = false, display = 'split', mode = mode })
end

return M
