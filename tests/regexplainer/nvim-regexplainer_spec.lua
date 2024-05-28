local Utils = require 'tests.helpers.util'

local regexplainer = require 'regexplainer'
local scan = require 'plenary.scandir'

local function file_filter(filename)
  local filter = vim.env.REGEXPLAINER_TEST_FILTER or nil
  if filter then
    return filename:match [[Sudoku]]
  else
    return #filename > 0
  end
end

local function row_filter(row)
  -- return row <= 12
  return true
end

local function category_filter(category)
 return (false
   or category == 'Simple Patterns'
   or category == 'Modifiers'
   or category == 'Ranges and Quantifiers'
   or category == 'Negated Ranges'
   or category == 'Capture Groups'
   or category == 'Named Capture Groups'
   or category == 'Non-Capturing Groups'
   or category == 'Alternations'
   or category == 'Lookaround'
   or category == 'Special Characters'
   or category == 'Practical Examples'
   or category == 'Regex Sudoku'
   or category == 'Errors'
 )
end

describe("Regexplainer", function()
  describe('Yank', function()
    it('yanks into a given register', function()
      regexplainer.setup()
      local bufnr = vim.api.nvim_create_buf(true, true)

      local expected = "Either `hello` or `world`\n"
      local actual = 'FAIL'

      vim.api.nvim_buf_call(bufnr, function()
        vim.bo.filetype = 'javascript'
        vim.api.nvim_set_current_line[[/hello|world/;]]
        vim.cmd [[:norm l]]
        regexplainer.yank(Utils.register_name)
        actual = vim.fn.getreg(Utils.register_name)
      end)

      return assert.are.same(expected, actual, 'contents of a')
    end)
  end)
  before_each(Utils.clear_test_state)
  describe('Narratives', function()
    local all_files = scan.scan_dir('tests/fixtures/narrative', { depth = 1 })
    local files = vim.tbl_filter(file_filter, all_files)
    for _, file in ipairs(files) do
      local category = file:gsub('tests/fixtures/narrative/%d+ (.*)%.js', '%1')
      if not category_filter(category) then
        print(require'ansicolors'('%{yellow}Skipping %{reset}') .. category)
      else
        describe(category, function()
          before_each(regexplainer.setup)
          for result in Utils.iter_regexes_with_descriptions(file) do
            if (row_filter(result.row)) then
              it('/'..result.pattern..'/', function()
                Utils.assert_string(result.pattern, result.expected, file .. ':' .. result.row)
              end)
            end
          end
        end)
      end
    end
  end)
end)
