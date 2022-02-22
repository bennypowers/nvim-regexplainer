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

function M.notify(value, level)
  return vim.notify(vim.inspect(value), level)
end

function M.escape_markdown(str)
  return str:gsub('_', '\\_'):gsub('*', '\\*'):gsub('`', '\\`')
end

return M
