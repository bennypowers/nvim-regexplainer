local regexplainer = require'regexplainer'
local M = {}

function M.clear_test_state()
  -- Create fresh window
  vim.cmd("top new | wincmd o")
  local keepbufnr = vim.api.nvim_get_current_buf()

  -- Clear regexplainer state
  regexplainer.teardown()

  -- Cleanup any remaining buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if bufnr ~= keepbufnr then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
  assert(#vim.api.nvim_tabpage_list_wins(0) == 1, "Failed to properly clear tab")
  assert(#vim.api.nvim_list_bufs() == 1, "Failed to properly clear buffers")
end

function M.editfile(testfile)
  vim.cmd("e " .. testfile)
  assert.are.same(
    vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"),
    vim.fn.fnamemodify(testfile, ":p")
  )
end

function M.assert_popup_text_at_row(row, expected)
  vim.api.nvim_win_set_cursor(0, { row, 2 })
  regexplainer.show()
  M.wait_for_buffer()
  local bufnr = require'regexplainer.buffers'.get_buffers()[1].bufnr
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false);
  local text = table.concat(lines, '\n')
  local regex = vim.api.nvim_buf_get_lines(0, 0, -1, false)[row]
  return assert.are.same(expected, text, row .. ': ' .. regex)
end

function M.sleep(n)
  os.execute("sleep " .. tonumber(n))
end

function M.wait_for_buffer()
  local buffers
  while not buffers do
    local gotten = require'regexplainer.buffers'.get_buffers()
    if gotten and #gotten > 0 then
      buffers = gotten
    else
      M.sleep(1)
    end
  end
  return buffers
end

--[[
    Copyright (c) 2013 Enrique García Cota

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]
-- <nowiki>
--- Unindent resets the indentation level of mulitline strings.
--  It is useful for multiline strings inside functions and large tables.
--  This module serves as a utility function for string parsing, [[Global
--  Lua Modules/Testharness|Testharness]] test suites, [[Global Lua
--  Modules/I18n|I18n]] datastores.
--
--  Lua supports multiline strings in the format `[[\n...\n]]`. In general,
--  Lua does not outdent indented multiline strings out of the box. Though
--  Lua supports variable indentation in multiline strings, custom logic is
--  necessary to reset the string's indentation. This module adopts a
--  flexible approach based on string scanning.
--
--  Unlike Penlight's `pl.text.dedent` behaviour where every line has the
--  indentation of the first line removed, the line prefixed with the least
--  non-tab whitespace is reset to zero indentation. Thus, the opening line
--  of the string may retain some indentation *if* there are lines of less
--  indentation terminating the string.
--
--  @script             unindent
--  @license            MIT
--  @release            stable
--  @author             [[User:8nml|8nml]]
--  @attribution        [[github:kikito|@kikito]] ([[github:kikito/inspect.lua/blob/master/spec/unindent.lua|Github]])
--  @param              {string} str Multiline string indented consistently.
--  @returns            {string} Unindented string.
function M.dedent(str)
  str = str:gsub(' +$', ''):gsub('^ +', '') -- remove spaces at start and end
  local level = math.huge
  local minPrefix = ''
  local len
  for prefix in str:gmatch('\n( +)') do
      len = #prefix
      if len < level then
          level = len
          minPrefix = prefix
      end
  end
  return (str:gsub('\n' .. minPrefix, '\n'):gsub('\n$', '')):gsub("^%s(.-)%s$", "%1")
end

return M
