local regexplainer = require 'regexplainer'
local tree = require 'regexplainer.utils.treesitter'
local LangUtils = require 'tests.helpers.lang_util'

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

describe('csharp', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)
  after_each(LangUtils.teardown_buffers)

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

  describe('narratives', function()
    for result in LangUtils.iter_lang_fixtures('tests/fixtures/csharp.cs', 'c_sharp') do
      it(result.pattern_text, function()
        LangUtils.assert_at_cursor(
          'tests/fixtures/csharp.cs', 'c_sharp',
          result.row, result.col,
          result.expected, 'csharp.cs:' .. result.row)
      end)
    end
  end)
end)
