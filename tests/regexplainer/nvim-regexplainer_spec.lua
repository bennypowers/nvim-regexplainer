local Utils = require'tests.helpers.util'
local log = require'regexplainer.utils'.debug

local regexplainer = require'regexplainer'
local scan = require'plenary.scandir'

local function setup_narrative()
  regexplainer.setup()
end

describe("Regexplainer", function()
  before_each(Utils.clear_test_state)
  describe('Narratives', function()
    local files = scan.scan_dir('tests/fixtures/narrative', { depth = 1 })
    for _, file in ipairs(files) do
      local category = file:gsub('tests/fixtures/narrative/%d+ (.*)%.js', '%1')
      describe(category, function ()
        before_each(setup_narrative)
        for result in Utils.iter_regexes_with_descriptions(file) do
          it(result.text, function ()
            Utils.assert_string(result.text, result.example, file .. ':' .. result.row)
          end)
        end
      end)
    end
  end)
end)

