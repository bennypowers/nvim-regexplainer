local regexplainer = require 'regexplainer'
local parsers = require "nvim-treesitter.parsers"

local get_node_text = vim.treesitter.query.get_node_text

---@diagnostic disable-next-line: unused-local
local log = require 'regexplainer.utils'.debug

local M = {}

M.register_name = 'test'

-- NOTE: ideally, we'd query for the jsdoc description as an injected language, but
-- so far I've been unable to make that happen, after that, I tried querying the JSDoc tree
-- from the line above the regexp, but that also proved difficult
-- so, at long last, we do some sring manipulation

local query_js = vim.treesitter.query.parse_query('javascript', [[
  (comment) @comment
  (expression_statement
    (regex)) @expr
  ]])

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

  return M.trim(table.concat(lines, '\n'))
end

local function get_cases()
  local results = {}
  local parser = parsers.get_parser(0)
  local tree = parser:parse()[1]

  for id, node in query_js:iter_captures(tree:root(), 0) do
    local name = query_js.captures[id] -- name of the capture in the query
    local prev = node:prev_sibling()
    if name == 'expr' and prev and prev:type() == 'comment' then
      local text = get_node_text(node:named_child('pattern'), 0)
      local expected = get_expected_from_jsdoc(get_node_text(prev, 0))
      table.insert(results, {
        text = text,
        example = expected,
        row = node:start(),
      })
    end
  end

  return results
end

function M.trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function M.editfile(testfile)
  vim.cmd("e " .. testfile)
  assert.are.same(
    vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"),
    vim.fn.fnamemodify(testfile, ":p")
  )
end

function M.iter_regexes_with_descriptions(filename)
  M.editfile(filename)
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

  -- Clear regexplainer state
  regexplainer.teardown()

  -- Cleanup any remaining buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    vim.cmd.bwipeout({ count = bufnr, bang = true })
  end

  -- Create fresh window
  vim.cmd.new()
  vim.cmd.only({ bang = true })

  assert(#vim.api.nvim_tabpage_list_wins(0) == 1, "Failed to properly clear tab")
  assert(vim.fn.getreg(M.register_name) == '', "Failed to properly clear register")
end

function M.assert_popup_text_at_row(row, expected)
  M.editfile(assert:get_parameter('fixture_filename'))
  local moved = pcall(vim.api.nvim_win_set_cursor, 0, { row, 1 })
  while moved == false do
    M.editfile(assert:get_parameter('fixture_filename'))
  end
  regexplainer.show()
  M.wait_for_regexplainer_buffer()
  local bufnr = require 'regexplainer.buffers'.get_buffers()[1].bufnr
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false);
  local text = table.concat(lines, '\n')
  local regex = vim.api.nvim_buf_get_lines(0, 0, -1, false)[row]
  return assert.are.same(expected, text, row .. ': ' .. regex)
end

function M.assert_string(regexp, expected, message)
  local bufnr = vim.api.nvim_create_buf(true, true)
  local buffers

  vim.api.nvim_buf_call(bufnr, function()
    vim.bo.filetype = 'javascript'
    vim.api.nvim_set_current_line(regexp)
    vim.cmd [[:norm l]]
    regexplainer.show()
    buffers = M.wait_for_regexplainer_buffer()
  end)

  local re_bufnr = buffers[1].bufnr
  local lines = vim.api.nvim_buf_get_lines(re_bufnr, 0, vim.api.nvim_buf_line_count(re_bufnr), false);
  local text = table.concat(lines, '\n')

  -- Cleanup any remaining buffers
  vim.api.nvim_buf_delete(bufnr, { force = true })

  return assert.are.same(expected, text, message)
end

function M.sleep(n)
  os.execute("sleep " .. tonumber(n))
end

function M.wait_for_regexplainer_buffer()
  local buffers = require 'regexplainer.buffers'.get_buffers()
  local count = 0
  while not #buffers and count < 20 do
    vim.cmd [[:norm l]]
    regexplainer.show()
    count = count + 1
    buffers = require 'regexplainer.buffers'.get_buffers()
  end
  return buffers
end

function M.get_info_on_capture(id, name, node, metadata)
  local yes, text = pcall(get_node_text, node, 0)
  return {
    id, name,
    text = yes and text or nil,
    metadata = metadata,
    type = node:type(),
    pos = table.pack(node:range())
  }
end

M.dedent = require 'plenary.strings'.dedent

return M
