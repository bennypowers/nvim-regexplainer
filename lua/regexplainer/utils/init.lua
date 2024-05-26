local M = {}

function M.map(mode, lhs, rhs, opts)
  local options = {
    noremap = true,
    silent = true
  }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  local stat, error = pcall(vim.api.nvim_set_keymap, mode, lhs, rhs, options)
  if not stat then
    vim.notify(error, vim.log.levels.ERROR)
  end
end

-- Composes vim.inspect witht vim.notify
--
function M.notify(value, level, options)
  return vim.notify(vim.inspect(value), level, options)
end

-- For debugging
function M.debug(...)
  vim.notify(table.concat(vim.tbl_map(vim.inspect, { ... }), '\n'))
end

-- Escape markdown syntax in a given string
--
function M.escape_markdown(str)
  -- return str
  --   :gsub('_',   [[\_]])
  --   :gsub('\\', [[\\]])
  --   :gsub('*',   [[\*]])
  --   :gsub('`',   [[\`]])
  --   :gsub('>',   [[\>]])
  --   :gsub('<',   [[\<]])
  return string.gsub(str, [==[([\_*`><])]==], [[\%1]])
end

local lookuptables = {}

setmetatable(lookuptables, { __mode = "v" }) -- make values weak

local function get_lookup(xs)
  local key = type(xs) == 'string' and xs or table.concat(xs, '-')
  if lookuptables[key] then return lookuptables[key]
  else
    local lookup = {}
    for _, v in ipairs(xs) do lookup[v] = true end
    lookuptables[key] = lookup
    return lookup
  end
end

--- Memoized `elem` predicate
---@generic T
---@param x  T   needle
---@param xs T[] haystack
--
function M.elem(x, xs)
  return get_lookup(xs)[x] or false
end

function M.get_cached(key)
  return lookuptables[key]
end

function M.set_cached(key, table)
  lookuptables[key] = table
end

return M
