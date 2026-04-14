local regexplainer = require 'regexplainer'
local buffers = require 'regexplainer.buffers'

local get_parser = vim.treesitter.get_parser
local get_node_text = vim.treesitter.get_node_text

local M = {}

local function trim(s)
  return (string.gsub(s, '^%s*(.-)%s*$', '%1'))
end

local function strip_comment_marker(text)
  if text:match '^//' then
    return text:gsub('^// ?', '')
  elseif text:match '^#' then
    return text:gsub('^# ?', '')
  end
  return text
end

local function get_buffer_text(bufnr)
  return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
end

---Open a fixture file and extract test cases using the language's regexplainer_test query.
---Each case has: expected (narrative text), row, col (cursor position), pattern_text.
---@param fixture_file string
---@param parser_lang string
---@return fun(): { expected: string, row: number, col: number, pattern_text: string }|nil
function M.iter_lang_fixtures(fixture_file, parser_lang)
  vim.cmd('e! ' .. fixture_file)
  vim.treesitter.start(0, parser_lang)
  local parser = get_parser(0, parser_lang)
  parser:parse()

  local lang_query = vim.treesitter.query.get(parser_lang, 'regexplainer_test')
  if not lang_query then
    error('could not get regexplainer_test query for ' .. parser_lang)
  end

  local tree = parser:parse()[1]
  local results = {}
  local comment_lines = {}

  for id, node in lang_query:iter_captures(tree:root(), 0) do
    local name = lang_query.captures[id]
    if name == 'test.comment' then
      local text = get_node_text(node, 0)
      text = strip_comment_marker(text)
      table.insert(comment_lines, text)
    elseif name == 'test.pattern' then
      if #comment_lines > 0 then
        local sr, sc = node:range()
        table.insert(results, {
          expected = trim(table.concat(comment_lines, '\n')),
          row = sr + 1,
          col = sc,
          pattern_text = get_node_text(node, 0),
        })
        comment_lines = {}
      end
    end
  end

  local index = 0
  return function()
    index = index + 1
    if index <= #results then
      return results[index]
    end
  end
end

---Open a fixture file, position cursor, run regexplainer, and assert the output.
---@param fixture_file string
---@param parser_lang string
---@param row number 1-indexed
---@param col number 0-indexed
---@param expected string
---@param message string
function M.assert_at_cursor(fixture_file, parser_lang, row, col, expected, message)
  vim.cmd('e! ' .. fixture_file)
  vim.treesitter.start(0, parser_lang)
  get_parser(0):parse()
  vim.api.nvim_win_set_cursor(0, { row, col })
  regexplainer.show()
  local buffer = buffers.get_last_buffer()
  assert(buffer, 'regexplainer did not produce output at ' .. row .. ':' .. col .. ' (' .. (message or '') .. ')')
  local text = get_buffer_text(buffer.bufnr)
  regexplainer.hide()
  return assert.are.same(expected, text, message)
end

function M.teardown_buffers()
  regexplainer.teardown()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

return M
