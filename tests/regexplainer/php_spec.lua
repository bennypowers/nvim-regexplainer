local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'
local tree = require 'regexplainer.utils.treesitter'

---@param code string
---@param cursor_row number 1-indexed
---@param cursor_col number 0-indexed
---@return number bufnr
local function setup_php_buffer(code, cursor_row, cursor_col)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.bo[bufnr].filetype = 'php'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(code, '\n'))
  vim.treesitter.start(bufnr, 'php')
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

describe('php support', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('detects regex in preg_match with single-quoted string', function()
    setup_php_buffer("<?php\npreg_match('/\\d+/', $str);", 2, 14)
    assert.is_true(tree.has_regexp_at_cursor())
  end)

  it('does not detect regex in a plain string', function()
    setup_php_buffer('<?php\n$x = "hello";', 2, 8)
    assert.is_false(tree.has_regexp_at_cursor())
  end)

  it('explains a simple pattern', function()
    setup_php_buffer("<?php\npreg_match('/hello/', $str);", 2, 14)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('`hello`', text)
  end)

  it('explains character class escapes', function()
    setup_php_buffer("<?php\npreg_match('/\\d+/', $str);", 2, 14)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('**0-9** (_>= 1x_)', text)
  end)

  it('strips flags from PCRE delimiters', function()
    setup_php_buffer("<?php\npreg_match('/hello/i', $str);", 2, 14)
    regexplainer.show()
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    local text = table.concat(lines, '\n')
    assert.are.same('`hello`', text)
  end)

  it('detects regex in preg_replace', function()
    setup_php_buffer("<?php\npreg_replace('/\\d+/', '', $str);", 2, 16)
    assert.is_true(tree.has_regexp_at_cursor())
  end)

  it('detects regex in preg_split', function()
    setup_php_buffer("<?php\npreg_split('/\\d+/', $str);", 2, 14)
    assert.is_true(tree.has_regexp_at_cursor())
  end)
end)
