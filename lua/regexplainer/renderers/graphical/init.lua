local graphics = require 'regexplainer.graphics'
local buffers = require 'regexplainer.buffers'
local utils = require 'regexplainer.utils'
local deps = require 'regexplainer.deps'
local cache = require 'regexplainer.cache'

local M = {}

---@class RegexplainerGraphicalRendererOptions
---@field width? number # Image width in pixels (default: 800)
---@field height? number # Image height in pixels (default: 600)
---@field python_cmd? string # Python command to use (default: 'python3')

--- Get the path to the railroad generator script
---@return string
local function get_script_path()
  local source = debug.getinfo(1, "S").source:sub(2)
  local script_dir = vim.fn.fnamemodify(source, ":h:h:h") .. "/python"
  return script_dir .. "/railroad_generator.py"
end

--- Get consistent terminal font dimensions
---@return number char_width, number char_height
local function get_terminal_font_dimensions()
  -- Since hologram.nvim seems to be scaling images up dramatically,
  -- we need to use much smaller "virtual" character dimensions
  -- to generate appropriately sized images
  return 2, 4  -- Much smaller to counteract scaling (was 8, 16)
end

--- Calculate optimal image size based on font size constraints
---@return number width, number height
local function calculate_image_size()
  -- Get current window dimensions
  local winid = vim.api.nvim_get_current_win()
  local win_width = vim.api.nvim_win_get_width(winid)
  local win_height = vim.api.nvim_win_get_height(winid)
  
  -- Get terminal font dimensions (consistent with popup sizing)
  local char_width, char_height = get_terminal_font_dimensions()
  
  -- Text in image should be between 0.5 and 2 terminal rows in height
  -- Railroad diagram text is typically around 12-14px font size
  local min_text_height = char_height * 0.5  -- 8px minimum
  local max_text_height = char_height * 2.0  -- 32px maximum
  local ideal_text_height = char_height * 1.2 -- 19.2px ideal
  
  -- Estimate railroad diagram dimensions based on text size constraints
  -- Railroad diagrams typically need 3-4x the text height for spacing and connections
  local diagram_height_ratio = 3.5
  local ideal_diagram_height = ideal_text_height * diagram_height_ratio
  
  -- Calculate initial pixel dimensions
  local pixel_width = math.floor(win_width * char_width * 0.75) -- 75% of window width
  local pixel_height = math.floor(ideal_diagram_height)
  
  -- Apply initial constraints
  pixel_width = math.max(200, math.min(600, pixel_width))
  pixel_height = math.max(min_text_height * diagram_height_ratio, 
                         math.min(max_text_height * diagram_height_ratio, pixel_height))
  
  -- Convert to character dimensions and apply popup constraints
  local char_cols = math.ceil(pixel_width / char_width)
  local char_rows = math.ceil(pixel_height / char_height)
  
  -- Apply popup size constraints
  local constrained_char_cols = math.max(30, math.min(char_cols, math.floor(win_width * 0.9)))
  local constrained_char_rows = math.max(5, math.min(char_rows, 40))
  
  -- Convert back to final pixel dimensions
  local final_pixel_width = constrained_char_cols * char_width
  local final_pixel_height = constrained_char_rows * char_height
  
  -- EXPERIMENTAL: Force very small images to counteract massive scaling
  -- If 50px displays as ~42 rows, we need images about 13x smaller
  final_pixel_width = 8   -- Extremely tiny width
  final_pixel_height = 4  -- Extremely tiny height
  
  return math.floor(final_pixel_width), math.floor(final_pixel_height)
end

--- Call Python script to generate railroad diagram
---@param components RegexplainerComponent[] # Components to render
---@param options RegexplainerOptions # Renderer options
---@param pattern_text string # Original regex pattern for caching
---@return string|nil base64_data # Base64 encoded PNG data, or nil on error
local function generate_railroad_diagram(components, options, pattern_text)
  local graphical_opts = options.graphical or {}
  
  -- Calculate optimal size based on window, or use configured size
  local width, height
  if graphical_opts.width and graphical_opts.height then
    width = graphical_opts.width
    height = graphical_opts.height
  else
    width, height = calculate_image_size()
  end
  
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
  local cmd = string.format('%s %s %s %d %d %s', 
    vim.fn.shellescape(python_cmd),
    vim.fn.shellescape(script_path),
    escaped_json,
    width,
    height,
    'true'  -- Always use dark theme
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
  
  -- Cache the generated image
  cache.cache_image(pattern_text, width, height, result)
  
  return result
end

--- Check if graphical rendering is available
---@param options RegexplainerOptions
---@return boolean available
---@return string? reason # Reason if not available
local function is_graphical_available(options)
  -- Check if graphics protocol is supported
  if not graphics.is_graphics_supported() then
    return false, "No supported graphics protocol (Kitty graphics protocol required)"
  end
  
  -- Check if Python script exists
  local script_path = get_script_path()
  if vim.fn.filereadable(script_path) ~= 1 then
    return false, "Railroad generator script not found at: " .. script_path
  end
  
  -- Check if Python and dependencies are available
  local graphical_opts = options.graphical or {}
  local deps_config = vim.tbl_deep_extend('force', options.deps or {}, graphical_opts)
  local python_cmd, err = deps.get_python_cmd(deps_config, options)
  if not python_cmd then
    return false, err or "Python dependencies not available"
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
  
  -- Generate railroad diagram
  local pattern_text = state.full_regexp_text or ""
  local base64_data = generate_railroad_diagram(components, options, pattern_text)
  
  if options.debug then
    if base64_data then
      utils.notify(string.format('Generated railroad diagram: %d bytes of base64', #base64_data), 'info')
    else
      utils.notify('Failed to generate railroad diagram', 'error')
    end
  end
  
  if not base64_data then
    if options.debug then
      utils.notify('Failed to generate railroad diagram, falling back to narrative', 'warning')
    end
    
    -- Fallback to narrative renderer
    local narrative = require 'regexplainer.renderers.narrative'
    return narrative.get_lines(components, options, state)
  end
  
  
  -- Store image data in state for set_lines to use
  state.image_data = base64_data
  
  -- Calculate character dimensions for popup sizing using consistent font dimensions
  local char_width, char_height = get_terminal_font_dimensions()
  
  local image_width, image_height
  -- NOW I UNDERSTAND: hologram displays 1 pixel ≈ 1 character
  -- So generate images at character dimensions, not huge pixel dimensions!
  
  -- Get current window width
  local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
  
  -- Calculate constraints based on window size
  local max_char_width = math.min(80, math.floor(current_win_width * 0.8))  -- 80% of window, max 80 chars
  local max_char_height = 20  -- Maximum popup height
  
  -- Start with reasonable base dimensions for railroad diagrams
  -- Railroad diagrams are typically very wide and relatively short
  local base_width = 400   -- Good base width for readable text
  local base_height = 40   -- Much shorter - railroad diagrams are typically 8:1 to 10:1 ratio
  
  -- Only scale DOWN if the base width exceeds popup width constraint
  -- Let height be determined naturally by the content
  local scale_factor = 1.0
  if base_width > max_char_width then
    scale_factor = max_char_width / base_width
  end
  -- Don't force height constraints - let railroad diagrams be their natural height
  
  -- Apply scaling (only down, never up)
  image_width = math.floor(base_width * scale_factor)
  image_height = math.floor(base_height * scale_factor)
  
  -- These will be the popup dimensions in characters
  local popup_char_width = image_width   -- 1 pixel = 1 character in hologram
  local popup_char_height = image_height
  
  if options.debug then
    utils.notify(string.format('Base: %dx%d, Scale: %.2f, Final: %dx%d pixels/chars', 
      base_width, base_height, scale_factor, image_width, image_height), 'info')
  end
  
  -- Original logic (commented out for debugging):
  -- if options.graphical and options.graphical.width and options.graphical.height then
  --   image_width = options.graphical.width
  --   image_height = options.graphical.height
  -- else
  --   image_width, image_height = calculate_image_size()
  -- end
  
  -- Since hologram displays 1 pixel ≈ 1 character, the character dimensions 
  -- are approximately the same as the pixel dimensions
  local char_cols = image_width
  local char_rows = image_height
  
  -- Debug: Check the calculations
  if options.debug then
    utils.notify(string.format('Image: %dx%d pixels ≈ %dx%d chars in hologram', 
      image_width, image_height, char_cols, char_rows), 'info')
  end
  
  -- Store dimensions for popup sizing and image display
  state.image_char_width = popup_char_width  -- Use calculated dimensions for popup
  state.image_char_height = popup_char_height
  state.graphical_opts = {
    width = image_width,   -- Use pixel dimensions for image generation
    height = image_height
  }
  
  -- Return empty lines - image will be displayed directly in popup
  return { }
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
    if options.debug then
      utils.notify(string.format('Displaying image: %d bytes to buffer %s', #state.image_data, buffer and buffer.bufnr or 'current'), 'info')
    end
    
    -- Add a small delay to ensure the window is fully rendered
    vim.defer_fn(function()
      local opts = state.graphical_opts or {}
      
      -- Get the buffer number for the popup/display window
      local target_bufnr = buffer and buffer.bufnr or vim.api.nvim_get_current_buf()
      
      if options.debug then
        utils.notify(string.format('Calling graphics.display_image with bufnr: %s', target_bufnr), 'info')
      end
      
      local success = graphics.display_image(state.image_data, {
        width = opts.width,
        height = opts.height,
        buffer = target_bufnr  -- Pass buffer info to graphics module
      })
      
      if options.debug then
        utils.notify(string.format('graphics.display_image returned: %s', success and 'true' or 'false'), 'info')
      end
    end, 200) -- 200ms delay
  else
    if options.debug then
      utils.notify('No image data in state - not displaying image', 'warning')
    end
  end
end

return M