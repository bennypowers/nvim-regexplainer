local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'
local tree = require 'regexplainer.utils.treesitter'

---@param code string
---@param cursor_row number 1-indexed
---@param cursor_col number 0-indexed
---@return number bufnr
local function setup_csharp_buffer(code, cursor_row, cursor_col)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.bo[bufnr].filetype = 'cs'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(code, '\n'))
  vim.treesitter.start(bufnr, 'c_sharp')
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

describe('csharp support', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('detects regex in new Regex with verbatim string', function()
    setup_csharp_buffer(
      'using System.Text.RegularExpressions;\nvar r = new Regex(@"\\d+");',
      2, 20)
    assert.is_true(tree.has_regexp_at_cursor())
  end)

  it('does not detect regex in a plain string', function()
    setup_csharp_buffer('string x = "hello";', 1, 14)
    assert.is_false(tree.has_regexp_at_cursor())
  end)

  it('explains a simple pattern from verbatim string', function()
    setup_csharp_buffer(
      'using System.Text.RegularExpressions;\nvar r = new Regex(@"hello");',
      2, 20)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('`hello`', text)
  end)

  it('explains character class escapes from verbatim string', function()
    setup_csharp_buffer(
      'using System.Text.RegularExpressions;\nvar r = new Regex(@"\\d+");',
      2, 20)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('**0-9** (_>= 1x_)', text)
  end)

  it('explains character class escapes from regular string', function()
    setup_csharp_buffer(
      'using System.Text.RegularExpressions;\nvar r = new Regex("\\\\d+");',
      2, 20)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('**0-9** (_>= 1x_)', text)
  end)

  it('detects regex in Regex.IsMatch', function()
    setup_csharp_buffer(
      'using System.Text.RegularExpressions;\nbool b = Regex.IsMatch(str, @"\\d+");',
      2, 30)
    assert.is_true(tree.has_regexp_at_cursor())
  end)
end)
