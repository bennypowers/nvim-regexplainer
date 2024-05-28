local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'
local parsers = require "nvim-treesitter.parsers"

local get_parser = vim.treesitter.get_parser
local get_node_text = vim.treesitter.get_node_text
local bd = vim.api.nvim_buf_delete

local query = vim.treesitter.query.get('javascript', 'regexplainer_test')
if not query then error('could not get query') end

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function editfile(testfile)
  vim.cmd("e! " .. testfile)
  assert.are.same(
    vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"),
    vim.fn.fnamemodify(testfile, ":p")
  )
end

---Parse a JSDoc comment, returning the markdown description
---@param comment string JSDoc comment, including /* */
---@return string description JSDoc description, without /* * */
local function get_expected_from_jsdoc(comment)
  local lines = {}
  for line in comment:gmatch("([^\n]*)\n?") do
    local clean = line
        :gsub('^/%*%*', '')
        :gsub('%*/$', '')
        :gsub('%s+%* ?', '', 1)
        :gsub('@example EXPECTED%: ?', '')
    table.insert(lines, clean)
  end

  return trim(table.concat(lines, '\n'))
end

---Retrieve all the cases in a fixture file.
---a case is a regexp expression with a JSDoc comment
---containing the expected regexplainer narrative result
local function get_cases()
  local results = {}
  local parser = parsers.get_parser(0)
  local tree = parser:parse()[1]
  local next = {}
  for id, node in query:iter_captures(tree:root(), 0) do
    local name = query.captures[id] -- name of the capture in the query
    if name == 'test.comment' then
      local jsdoc_text = get_node_text(node, 0);
      next.expected = get_expected_from_jsdoc(jsdoc_text)
    elseif name == 'test.pattern' then
      next.pattern = get_node_text(node, 0)
      next.row = node:start() + 1
    end
    if next.row and next.expected and next.pattern then
      table.insert(results, next)
      next = {}
    end
  end
  return results
end

---Cleanup any remaining buffers
local function clear_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param bufnr number
---@return string text buffer text
local function get_buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

---@param pattern string regexp pattern to test
---@return number bufnr bufnr of test fixture buffer
local function setup_test_buffer(pattern)
  local newbuf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, newbuf)
  vim.opt_local.filetype = 'javascript'
  vim.api.nvim_set_current_line('/'..pattern..'/;')
  vim.treesitter.start(newbuf, 'javascript')
  return newbuf
end

local function show_and_get_regexplainer_buffer(bufnr)
  local buffer
  repeat
    get_parser(0):parse()
    vim.uv.sleep(1)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0));
    vim.api.nvim_win_set_cursor(0, {row, col + 1})
    local cursor_node = vim.treesitter.get_node()
    if (cursor_node) then
      for id, node in query:iter_captures(cursor_node, bufnr) do
        if query[id] == 'test.pattern' and node then
          local range = node:range()
          vim.api.nvim_win_set_cursor(0, { range[0], range[1] })
        end
      end
    end
    regexplainer.show({debug = true})
    buffer = buffers.get_last_buffer()
  until buffer
  return buffer.bufnr
end

local M = {}

M.register_name = 'test'

function M.iter_regexes_with_descriptions(filename)
  editfile(filename)
  local cases = get_cases()
  local index = 0
  return function()
    index = index + 1
    if index <= #cases then
      return cases[index]
    end
  end
end

function M.clear_test_state()
  vim.fn.setreg(M.register_name, '')
  regexplainer.teardown() -- Clear regexplainer state
  clear_buffers()
  assert(#vim.api.nvim_list_bufs() == 1, "Failed to properly clear buffers")
  assert(#vim.api.nvim_tabpage_list_wins(0) == 1, "Failed to properly clear tab")
  assert(vim.fn.getreg(M.register_name) == '', "Failed to properly clear register")
end

---@param pattern string regexp pattern to test
---@param expected string expected markdown output
---@param message string test description
function M.assert_string(pattern, expected, message)
  local newbufnr = setup_test_buffer(pattern)
  local rebufnr = show_and_get_regexplainer_buffer(newbufnr)
  local text = get_buffer_text(rebufnr)
  -- Cleanup any remaining buffers
  bd(newbufnr, { force = true })
  regexplainer.hide()
  return assert.are.same(expected, text, message)
end

return M
