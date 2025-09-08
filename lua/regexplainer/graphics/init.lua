---@class RegexplainerGraphicsProtocol
---@field name string # Protocol name (e.g., "kitty", "sixel")
---@field is_supported fun(): boolean # Check if protocol is supported in current terminal
---@field display_image fun(base64_data: string, width?: number, height?: number): boolean # Display image, returns success

---@class RegexplainerGraphicsOptions
---@field width? number # Image width in pixels
---@field height? number # Image height in pixels
---@field fallback? boolean # Whether to fallback to text if graphics fail

local M = {}

---@type table<string, RegexplainerGraphicsProtocol>
local protocols = {}

--- Register a graphics protocol
---@param protocol RegexplainerGraphicsProtocol
function M.register_protocol(protocol)
  protocols[protocol.name] = protocol
end

--- Get the first supported graphics protocol
---@return RegexplainerGraphicsProtocol|nil
function M.get_supported_protocol()
  -- Use hologram as the primary protocol
  local protocol = protocols['hologram']

  if protocol then
    local supported = protocol.is_supported()
    if supported then
      return protocol
    end
  end

  return nil
end

--- Display an image using the best available protocol
---@param base64_data string # Base64 encoded image data
---@param options? RegexplainerGraphicsOptions # Display options
---@return boolean # True if successfully displayed
function M.display_image(base64_data, options)
  options = options or {}

  local protocol = M.get_supported_protocol()
  if not protocol then
    return false
  end

  local result = protocol.display_image(base64_data, options.width, options.height, options.buffer)

  return result
end

--- Check if any graphics protocol is supported
---@return boolean
function M.is_graphics_supported()
  return M.get_supported_protocol() ~= nil
end

--- Get list of available protocol names
---@return string[]
function M.get_available_protocols()
  local names = {}
  for name, protocol in pairs(protocols) do
    if protocol.is_supported() then
      table.insert(names, name)
    end
  end
  return names
end

-- Load and register available protocols
local hologram = require 'regexplainer.graphics.hologram'
M.register_protocol(hologram.protocol)

return M
