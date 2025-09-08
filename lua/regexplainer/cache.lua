---@class RegexplainerCache
local M = {}

-- In-memory cache for generated images
---@type table<string, {base64_data: string, width: number, height: number, timestamp: number}>
local image_cache = {}

-- Cache expiration time in seconds (30 minutes)
local CACHE_EXPIRATION = 30 * 60

--- Generate a cache key from pattern and options
---@param pattern string # The regex pattern
---@param width number # Image width
---@param height number # Image height
---@return string # Cache key
local function generate_cache_key(pattern, width, height)
  return string.format('%s:%dx%d', pattern, width, height)
end

--- Clean expired entries from cache
local function clean_expired_entries()
  local current_time = os.time()
  local expired_keys = {}

  for key, entry in pairs(image_cache) do
    if current_time - entry.timestamp > CACHE_EXPIRATION then
      table.insert(expired_keys, key)
    end
  end

  for _, key in ipairs(expired_keys) do
    image_cache[key] = nil
  end
end

--- Get cached image data
---@param pattern string # The regex pattern
---@param width number # Image width
---@param height number # Image height
---@return table|nil # Cached data table {base64, actual_width, actual_height}, or nil if not found
function M.get_cached_image(pattern, width, height)
  clean_expired_entries()

  local key = generate_cache_key(pattern, width, height)
  local entry = image_cache[key]

  if entry then
    -- Update timestamp to refresh cache entry
    entry.timestamp = os.time()
    return {
      base64 = entry.base64_data,
      actual_width = entry.width,
      actual_height = entry.height,
    }
  end

  return nil
end

--- Cache generated image data
---@param pattern string # The regex pattern
---@param width number # Image generation width (for cache key)
---@param height number # Image generation height (for cache key)
---@param base64_data string # Base64 encoded image data
---@param actual_width? number # Actual trimmed image width
---@param actual_height? number # Actual trimmed image height
function M.cache_image(pattern, width, height, base64_data, actual_width, actual_height)
  clean_expired_entries()

  local key = generate_cache_key(pattern, width, height)
  image_cache[key] = {
    base64_data = base64_data,
    width = actual_width or width,
    height = actual_height or height,
    timestamp = os.time(),
  }
end

--- Clear all cached images
function M.clear_cache()
  image_cache = {}
end

--- Get cache statistics
---@return {entries: number, total_size: number}
function M.get_cache_stats()
  local entries = 0
  local total_size = 0

  for _, entry in pairs(image_cache) do
    entries = entries + 1
    total_size = total_size + #entry.base64_data
  end

  return {
    entries = entries,
    total_size = total_size,
  }
end

return M
