local regexplainer = require'regexplainer'

local M = {}

function M.clear_test_state()
  -- Clear regexplainer state
  regexplainer.teardown()

  -- Create fresh window
  vim.cmd("top new | wincmd o")
  local keepbufnr = vim.api.nvim_get_current_buf()

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
  M.editfile(assert:get_parameter('fixture_filename'))
  local moved = pcall(vim.api.nvim_win_set_cursor, 0, { row, 2 })
  while moved == false do
    M.editfile(assert:get_parameter('fixture_filename'))
  end
  regexplainer.show()
  M.wait_for_regexplainer_buffer()
  local bufnr = require'regexplainer.buffers'.get_buffers()[1].bufnr
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false);
  local text = table.concat(lines, '\n')
  local regex = vim.api.nvim_buf_get_lines(0, 0, -1, false)[row]
  return assert.are.same(expected, text, row .. ': ' .. regex)
end

function M.sleep(n)
  os.execute("sleep " .. tonumber(n))
end

function M.wait_for_regexplainer_buffer()
  local buffers
  while not buffers do
    local gotten = require'regexplainer.buffers'.get_buffers()
    if gotten and #gotten > 0 then
      buffers = gotten
    else
      M.sleep(0.1)
    end
  end
  return buffers
end

local getIndentPreffix = function(str)
  local level = math.huge
  local minPreffix = ""
  local len
  for preffix in str:gmatch("\n( +)") do
    len = #preffix
    if len < level then
      level = len
      minPreffix = preffix
    end
  end
  return minPreffix
end

function M.dedent(str)
  str = str:gsub(" +$", ""):gsub("^ +", "") -- remove spaces at start and end
  local preffix = getIndentPreffix(str)
  return (str:gsub("\n" .. preffix, "\n"):gsub("\n$", ""))
end


return M
