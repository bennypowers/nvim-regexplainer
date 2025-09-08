local graphics = require 'regexplainer.graphics'
local buffers = require 'regexplainer.buffers'
local utils = require 'regexplainer.utils'
local deps = require 'regexplainer.deps'
local cache = require 'regexplainer.cache'

local M = {}

-- Configuration constants
local DEFAULT_GENERATION_WIDTH = 1200 -- Large enough for any railroad diagram
local DEFAULT_GENERATION_HEIGHT = 800 -- Large enough for any railroad diagram

---@class RegexplainerGraphicalRendererOptions
---@field width? number # Image width in pixels (default: 800)
---@field height? number # Image height in pixels (default: 600)
---@field python_cmd? string # Python command to use (default: 'python3')
---@field generation_width? number # Width for initial image generation (default: 1200)
---@field generation_height? number # Height for initial image generation (default: 800)

--- Get the path to the railroad generator script
---@return string
local function get_script_path()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local script_dir = vim.fn.fnamemodify(source, ':h:h:h') .. '/python'
  return script_dir .. '/railroad_generator.py'
end

--- Call Python script to generate railroad diagram
---@param components RegexplainerComponent[] # Components to render
---@param options RegexplainerOptions # Renderer options
---@param pattern_text string # Original regex pattern for caching
---@return string|nil base64_data # Base64 encoded PNG data, or nil on error
local function generate_railroad_diagram(components, options, pattern_text)
  local graphical_opts = options.graphical or {}

  -- Always generate at full readable size (Python will trim to actual content)
  local width = graphical_opts.generation_width or DEFAULT_GENERATION_WIDTH
  local height = graphical_opts.generation_height or DEFAULT_GENERATION_HEIGHT

  -- Check cache first
  local cached_data = cache.get_cached_image(pattern_text, width, height)
  if cached_data then
    return cached_data
  end

  -- Get managed Python executable
  local deps_config = vim.tbl_deep_extend('force', options.deps or {}, graphical_opts)
  local python_cmd, err = deps.get_python_cmd(deps_config, options)
  if not python_cmd then
    if options.debug then
      utils.notify('Failed to get Python executable: ' .. (err or 'unknown error'), 'error')
    end
    return nil
  end

  local script_path = get_script_path()

  -- Convert components to JSON
  local components_json = vim.fn.json_encode(components)

  -- Escape the JSON for shell command
  local escaped_json = vim.fn.shellescape(components_json)

  -- Build command with dark theme parameter
  local cmd = string.format(
    '%s %s %s %d %d %s',
    vim.fn.shellescape(python_cmd),
    vim.fn.shellescape(script_path),
    escaped_json,
    width,
    height,
    'true' -- Always use dark theme
  )

  -- Execute command and capture output
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    if options.debug then
      utils.notify('Python script failed with exit code: ' .. exit_code, 'error')
      utils.notify('Error output: ' .. result, 'error')
    end
    return nil
  end

  -- Trim whitespace from result
  result = vim.trim(result)

  if result == '' then
    if options.debug then
      utils.notify('Python script returned empty result', 'error')
    end
    return nil
  end

  -- Parse JSON response to get base64 data and actual dimensions
  local ok, parsed = pcall(vim.fn.json_decode, result)
  if not ok or not parsed or not parsed.base64 then
    if options.debug then
      utils.notify('Failed to parse Python script JSON response', 'error')
    end
    return nil
  end

  -- Cache the generated image data using generation parameters as key, actual dimensions as values
  cache.cache_image(pattern_text, width, height, parsed.base64, parsed.width, parsed.height)

  -- Return both base64 data and actual dimensions
  return {
    base64 = parsed.base64,
    actual_width = parsed.width,
    actual_height = parsed.height,
  }
end

--- Check if graphical rendering is available
---@param options RegexplainerOptions
---@return boolean available
---@return string? reason # Reason if not available
local function is_graphical_available(options)
  -- Check if graphics protocol is supported
  if not graphics.is_graphics_supported() then
    return false, 'No supported graphics protocol (Kitty graphics protocol required)'
  end

  -- Check if Python script exists
  local script_path = get_script_path()
  if vim.fn.filereadable(script_path) ~= 1 then
    return false, 'Railroad generator script not found at: ' .. script_path
  end

  -- Check if Python and dependencies are available
  local graphical_opts = options.graphical or {}
  local deps_config = vim.tbl_deep_extend('force', options.deps or {}, graphical_opts)
  local python_cmd, err = deps.get_python_cmd(deps_config, options)
  if not python_cmd then
    return false, err or 'Python dependencies not available'
  end

  return true, nil
end

--- Generate lines for graphical display
---@param components RegexplainerComponent[] # Components to render
---@param options RegexplainerOptions # Renderer options
---@param state RegexplainerRendererState # Renderer state
---@return string[] lines # Lines to display (may include fallback text)
function M.get_lines(components, options, state)
  local available, reason = is_graphical_available(options)

  if not available then
    if options.debug then
      utils.notify('Graphical rendering not available: ' .. (reason or 'unknown'), 'warning')
    end

    -- Fallback to narrative renderer
    local narrative = require 'regexplainer.renderers.narrative'
    return narrative.get_lines(components, options, state)
  end

  -- Generate railroad diagram at full size first to get natural aspect ratio
  local pattern_text = state.full_regexp_text or ''
  local diagram_result = generate_railroad_diagram(components, options, pattern_text)

  if not diagram_result or not diagram_result.base64 then
    if options.debug then
      utils.notify('Failed to generate railroad diagram, falling back to narrative', 'warning')
    end

    -- Fallback to narrative renderer
    local narrative = require 'regexplainer.renderers.narrative'
    return narrative.get_lines(components, options, state)
  end

  -- Extract actual image dimensions from generated result
  local actual_width = diagram_result.actual_width
  local actual_height = diagram_result.actual_height
  local base64_data = diagram_result.base64

  if options.debug then
    utils.notify(
      string.format(
        'Generated railroad diagram: %d bytes, actual size: %dx%d pixels',
        #base64_data,
        actual_width,
        actual_height
      ),
      'info'
    )
  end

  -- Get character cell dimensions for aspect ratio compensation
  local hologram_state = require 'hologram.state'
  hologram_state.update_cell_size()
  local cell_width = hologram_state.cell_size.x -- pixels per character width
  local cell_height = hologram_state.cell_size.y -- pixels per character height

  -- Calculate window constraints
  local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
  local current_win_height = vim.api.nvim_win_get_height(vim.api.nvim_get_current_win())
  local max_popup_char_width = math.floor(current_win_width * 0.9) -- 90% of window width
  local max_popup_char_height = math.floor(current_win_height * 0.7) -- 70% of window height

  -- Convert character constraints to effective pixel constraints
  -- Account for the fact that characters will stretch the image
  local max_effective_width = max_popup_char_width * cell_width
  local max_effective_height = max_popup_char_height * cell_height

  local final_width, final_height

  -- Check if image needs scaling to fit window
  if actual_width <= max_effective_width and actual_height <= max_effective_height then
    -- Image fits - use original size
    final_width = actual_width
    final_height = actual_height

    if options.debug then
      utils.notify(string.format('Image fits: %dx%d pixels', actual_width, actual_height), 'info')
    end
  else
    -- Image too large - scale down while preserving aspect ratio
    local scale_x = max_effective_width / actual_width
    local scale_y = max_effective_height / actual_height
    local scale = math.min(scale_x, scale_y) -- Preserve aspect ratio

    final_width = math.floor(actual_width * scale)
    final_height = math.floor(actual_height * scale)

    -- Regenerate at the correct size
    diagram_result = generate_railroad_diagram(components, options, pattern_text, final_width, final_height)
    if diagram_result and diagram_result.base64 then
      base64_data = diagram_result.base64
      actual_width = diagram_result.actual_width
      actual_height = diagram_result.actual_height
      final_width = actual_width
      final_height = actual_height
    end
  end

  -- Set popup dimensions (converting from pixels to characters)
  local popup_char_width = math.ceil(final_width / cell_width)
  local popup_char_height = math.ceil(final_height / cell_height)

  -- Store image data in state for set_lines to use
  state.image_data = base64_data

  -- Store dimensions for popup sizing and image display
  state.image_char_width = popup_char_width -- Use calculated character dimensions
  state.image_char_height = popup_char_height
  state.graphical_opts = {
    width = final_width, -- Use final pixel dimensions (no hologram scaling)
    height = final_height,
  }

  -- Return empty lines - image will be displayed directly in popup
  return {}
end

--- Set lines in buffer and display image
---@param buffer RegexplainerBuffer # Buffer to render to
---@param lines string[] # Lines to set
---@return string[] lines # The lines that were set
function M.set_lines(buffer, lines)
  -- Set text lines first (like narrative renderer)
  if buffers.is_scratch(buffer) then
    vim.api.nvim_buf_set_lines(buffer.bufnr, 0, #lines, false, lines)
  elseif buffer.winid then
    vim.api.nvim_win_call(buffer.winid, function()
      vim.lsp.util.stylize_markdown(buffer.bufnr, lines, {})
    end)
  end

  return lines
end

--- Custom after hook to display image after buffer is set up
---@param buffer RegexplainerBuffer # Buffer to render to
---@param lines string[] # Lines that were set
---@param options RegexplainerOptions # Renderer options
---@param state RegexplainerRendererState # Renderer state
function M.after_render(buffer, lines, options, state)
  if options.debug then
    utils.notify('after_render called', 'info')
    utils.notify(string.format('Buffer: %s, Lines: %d', buffer and buffer.bufnr or 'nil', #lines), 'info')
    utils.notify(string.format('State has image_data: %s', state and state.image_data and 'yes' or 'no'), 'info')
  end

  -- Display railroad diagram image if we have image data
  if state and state.image_data then
    -- Skip image display for split mode - it handles its own image display
    if buffer and buffer.type == 'NuiSplit' then
      if options.debug then
        utils.notify('Skipping after_render image display for split mode', 'info')
      end
      return
    end

    -- Add a small delay to ensure the window is fully rendered
    vim.defer_fn(function()
      local opts = state.graphical_opts or {}

      -- Get the buffer number for the popup/display window
      local target_bufnr = buffer and buffer.bufnr or vim.api.nvim_get_current_buf()

      local success = graphics.display_image(state.image_data, {
        width = opts.width,
        height = opts.height,
        buffer = target_bufnr, -- Pass buffer info to graphics module
      })

      -- Pattern popup will be created in popup buffer's after() callback
    end, 200) -- 200ms delay
  else
    if options.debug then
      utils.notify('No image data in state - not displaying image', 'warning')
    end
  end
end

return M
