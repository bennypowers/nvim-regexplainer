local Utils = require 'tests.helpers.util'
local log = require 'regexplainer.utils'.debug

local regexplainer = require 'regexplainer'
local scan = require 'plenary.scandir'

local function setup_narrative()
  regexplainer.setup()
end

local function file_filter(filename)
  local filter = vim.env.REGEXPLAINER_TEST_FILTER or nil
  if filter then
    return filename:match [[Sudoku]]
  else
    return #filename > 0
  end
end

local function row_filter(row)
  -- return row == 71
  return true
end

describe("Regexplainer", function()
  before_each(Utils.clear_test_state)
  describe('Narratives', function()
    local all_files = scan.scan_dir('tests/fixtures/narrative', { depth = 1 })
    local files = vim.tbl_filter(file_filter, all_files)
    for _, file in ipairs(files) do
      local category = file:gsub('tests/fixtures/narrative/%d+ (.*)%.js', '%1')
      describe(category, function()
        before_each(setup_narrative)
        for result in Utils.iter_regexes_with_descriptions(file) do
          if (row_filter(result.row)) then
            it(result.text, function()
              Utils.assert_string(result.text, result.example, file .. ':' .. result.row)
            end)
          end
        end
      end)
    end
  end)

  describe('Yank', function()
    it('yanks into a given register', function()
      local bufnr = vim.api.nvim_create_buf(true, true)

      vim.api.nvim_buf_call(bufnr, function()
        vim.bo.filetype = 'javascript'
        vim.api.nvim_set_current_line[[/hello|world/;]]
        vim.cmd [[:norm l]]
        regexplainer.yank(Utils.register_name)
      end)

      local actual = vim.fn.getreg(Utils.register_name)
      local expected = "`hello` or `world`"

      return assert.are.same(expected, actual, 'contents of a')
    end)
  end)
end)
