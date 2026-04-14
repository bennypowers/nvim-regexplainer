local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'
local tree = require 'regexplainer.utils.treesitter'

---@param code string
---@param cursor_row number 1-indexed
---@param cursor_col number 0-indexed
---@return number bufnr
local function setup_ruby_buffer(code, cursor_row, cursor_col)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.bo[bufnr].filetype = 'ruby'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(code, '\n'))
  vim.treesitter.start(bufnr, 'ruby')
  vim.treesitter.get_parser(bufnr):parse()
  vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col })
  return bufnr
end

local function teardown_buffers()
  regexplainer.teardown()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

describe('ruby support', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('detects regex at cursor', function()
    setup_ruby_buffer('x = /hello/', 1, 6)
    assert.is_true(tree.has_regexp_at_cursor())
  end)

  it('does not detect regex when cursor is on a string', function()
    setup_ruby_buffer('x = "hello"', 1, 6)
    assert.is_false(tree.has_regexp_at_cursor())
  end)

  it('explains a simple pattern', function()
    setup_ruby_buffer('x = /hello/', 1, 6)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('`hello`', text)
  end)

  it('explains a pattern with character class escapes', function()
    setup_ruby_buffer('x = /\\d+/', 1, 6)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('**0-9** (_>= 1x_)', text)
  end)

  it('explains a pattern with flags', function()
    setup_ruby_buffer('x = /hello/i', 1, 6)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('`hello`', text)
  end)
end)
