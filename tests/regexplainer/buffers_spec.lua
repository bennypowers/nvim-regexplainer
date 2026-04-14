local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'
local tree = require 'regexplainer.utils.treesitter'

---@param pattern string
---@return number bufnr
local function setup_js_buffer(pattern)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.bo[bufnr].filetype = 'javascript'
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'const x = /' .. pattern .. '/;' })
  vim.treesitter.start(bufnr, 'javascript')
  vim.treesitter.get_parser(bufnr):parse()
  -- position cursor inside the regex
  vim.api.nvim_win_set_cursor(0, { 1, 12 })
  return bufnr
end

local function teardown_buffers()
  regexplainer.teardown()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

describe('has_regexp_at_cursor', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('returns true when cursor is on a regex', function()
    setup_js_buffer('hello')
    assert.is_true(tree.has_regexp_at_cursor())
  end)

  it('returns false when cursor is not on a regex', function()
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.bo[bufnr].filetype = 'javascript'
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'const x = "hello";' })
    vim.treesitter.start(bufnr, 'javascript')
    vim.treesitter.get_parser(bufnr):parse()
    vim.api.nvim_win_set_cursor(0, { 1, 12 })
    assert.is_false(tree.has_regexp_at_cursor())
  end)
end)

describe('popup buffer', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('creates a popup with correct type', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'popup' }
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    assert.equals('Popup', buffer.type)
  end)

  it('mounts a floating window', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'popup' }
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer.winid)
    assert.is_true(vim.api.nvim_win_is_valid(buffer.winid))
    local config = vim.api.nvim_win_get_config(buffer.winid)
    -- nvim_open_win with relative='cursor' may be reported as 'win' by get_config
    assert.is_not_equal('', config.relative)
  end)

  it('unmounts cleanly', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'popup' }
    local buffer = buffers.get_last_buffer()
    local winid = buffer.winid
    local bufnr = buffer.bufnr
    regexplainer.hide()
    assert.is_false(vim.api.nvim_win_is_valid(winid))
    assert.is_false(vim.api.nvim_buf_is_valid(bufnr))
  end)

  it('does not modify buffer content for padding', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'popup' }
    local buffer = buffers.get_last_buffer()
    local lines = vim.api.nvim_buf_get_lines(buffer.bufnr, 0, -1, false)
    -- first line should not be blank (no content-based top padding)
    assert.is_not_equal('', lines[1])
  end)

  it('sets the border from config', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'popup' }
    local buffer = buffers.get_last_buffer()
    local config = vim.api.nvim_win_get_config(buffer.winid)
    assert.is_not_nil(config.border)
  end)
end)

describe('split buffer', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(teardown_buffers)

  it('creates a split with correct type', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'split' }
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    assert.equals('Split', buffer.type)
  end)

  it('mounts a non-floating window', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'split' }
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer.winid)
    assert.is_true(vim.api.nvim_win_is_valid(buffer.winid))
    local config = vim.api.nvim_win_get_config(buffer.winid)
    assert.equals('', config.relative)
  end)

  it('unmounts cleanly', function()
    setup_js_buffer('hello')
    regexplainer.show { display = 'split' }
    local buffer = buffers.get_last_buffer()
    assert.is_not_nil(buffer)
    assert.is_not_nil(buffer.winid)
    local winid = buffer.winid
    buffer:hide()
    buffer:unmount()
    assert.is_false(vim.api.nvim_win_is_valid(winid))
  end)

  it('does not steal focus from parent window', function()
    local parent_win = vim.api.nvim_get_current_win()
    setup_js_buffer('hello')
    regexplainer.show { display = 'split' }
    assert.equals(parent_win, vim.api.nvim_get_current_win())
  end)
end)
