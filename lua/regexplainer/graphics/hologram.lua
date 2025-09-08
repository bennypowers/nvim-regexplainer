local M = {}

--- Check if hologram.nvim is available
---@return boolean
local function is_hologram_available()
  local ok, hologram = pcall(require, 'hologram')
  local available = ok and hologram ~= nil

  -- Ensure hologram is set up if available
  if available then
    hologram.setup {
      auto_display = false, -- We handle display manually
    }
  end

  return available
end

--- Display an image using hologram.nvim
---@param base64_data string # Base64 encoded PNG data
---@param options? table # Display options: {width?, height?, buffer?}
---@return boolean # True if successfully displayed
local function display_image(base64_data, options)
  if not is_hologram_available() then
    return false
  end

  local ok, hologram = pcall(require, 'hologram')
  if not ok then
    return false
  end

  -- Decode base64 to get raw image data
  local ok_decode, image_data = pcall(function()
    return vim.base64.decode(base64_data)
  end)

  if not ok_decode then
    return false
  end

  -- Create a temporary file for the image
  local temp_file = '/tmp/regexplainer_' .. os.time() .. '_' .. math.random(1000, 9999) .. '.png'

  local file = io.open(temp_file, 'wb')
  if not file then
    return false
  end

  file:write(image_data)
  file:close()

  -- Verify the file was created and has content
  local file_info = vim.loop.fs_stat(temp_file)
  if not file_info then
    return false
  end

  options = options or {}
  
  -- Determine position for image placement
  local row, col, bufnr
  if options.buffer then
    -- Display within the popup content area
    row = 1  -- Position at top of popup content
    col = 0
    bufnr = options.buffer
  else
    -- Fallback: display at current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    row = cursor_pos[1]
    col = cursor_pos[2]
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Clean up any previous image
  if _G._regexplainer_hologram_image and _G._regexplainer_hologram_bufnr then
    pcall(function()
      _G._regexplainer_hologram_image:delete(_G._regexplainer_hologram_bufnr, { free = true })
    end)
  end

  -- Create hologram image object and display it
  local success, err = pcall(function()
    -- Require the image module directly
    local img_ok, image_module = pcall(require, 'hologram.image')
    if not img_ok then
      error('Could not require hologram.image module: ' .. tostring(image_module))
    end

    -- Create image object using the documented API
    local image_obj = image_module:new(temp_file, {})
    if not image_obj then
      error 'Failed to create hologram image object'
    end

    -- Display the image at natural size (let popup control visible area)
    -- Hologram scaling seems to cause vertical stretching issues
    local display_opts = {}

    local display_result = image_obj:display(row, col, bufnr, display_opts)

    -- Store image reference for cleanup
    _G._regexplainer_hologram_image = image_obj
    _G._regexplainer_hologram_bufnr = bufnr
  end)

  -- Clean up temporary file after a delay
  vim.defer_fn(function()
    os.remove(temp_file)
  end, 5000) -- Keep file for 5 seconds to ensure hologram can read it

  if success then
    return true
  else
    os.remove(temp_file) -- Clean up immediately on failure
    return false
  end
end

-- Protocol definition for registration
M.protocol = {
  name = 'hologram',
  is_supported = is_hologram_available,
  display_image = display_image,
}

return M
