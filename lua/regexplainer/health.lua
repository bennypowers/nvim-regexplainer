local M = {}

--- Test whether regex injection works for a given language by parsing a sample
--- string and checking whether the language tree at the regex position is 'regex'.
---@param filetype string
---@param source string
---@param row number 0-indexed row of a character inside the regex pattern
---@param col number 0-indexed col of a character inside the regex pattern
---@return boolean
local function test_regex_injection(filetype, source, row, col)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(source, '\n'))
  vim.bo[bufnr].filetype = filetype

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return false
  end

  parser:parse(true)
  local lang_ok, langtree = pcall(parser.language_for_range, parser, { row, col, row, col })
  vim.api.nvim_buf_delete(bufnr, { force = true })

  return lang_ok and langtree ~= nil and langtree:lang() == 'regex'
end

-- Samples: { filetype, source, row, col }
-- The row/col point at a character inside the regex pattern body.
local injection_samples = {
  { 'javascript', 'const x = /hello/', 0, 12 },
  { 'typescript', 'const x = /hello/', 0, 12 },
  { 'html', '<script>\nconst x = /hello/\n</script>', 1, 12 },
  { 'ruby', 'x = /hello/', 0, 5 },
}

--- Try to ensure a treesitter parser is available, installing if possible.
---@param lang string
---@return boolean
local function ensure_parser(lang)
  local ok = pcall(vim.treesitter.language.add, lang)
  if ok then return true end
  -- parser not installed, try to install it
  vim.health.info(lang .. ': parser not found, attempting install...')
  local install_ok, err = pcall(vim.treesitter.language.add, lang, { install = true })
  if install_ok then
    vim.health.ok(lang .. ': parser installed')
    return true
  end
  vim.health.warn(lang .. ': could not install parser: ' .. tostring(err))
  return false
end

M.check = function()
  vim.health.start('regexplainer: treesitter')

  if not ensure_parser('regex') then
    vim.health.error('regex parser is required', {
      'Install the regex parser for treesitter',
    })
  end

  for _, sample in ipairs(injection_samples) do
    local filetype, source, row, col = sample[1], sample[2], sample[3], sample[4]

    if not ensure_parser(filetype) then
      vim.health.warn(filetype .. ': parser not available (skipped)')
    else
      local inject_ok, result = pcall(test_regex_injection, filetype, source, row, col)
      if inject_ok and result then
        vim.health.ok(filetype .. ': regex injection working')
      elseif not inject_ok then
        vim.health.warn(filetype .. ': injection test failed (' .. tostring(result) .. ')')
      else
        vim.health.error(filetype .. ': regex injection not detected', {
          'Ensure the ' .. filetype .. ' treesitter parser is up to date',
        })
      end
    end
  end

  -- Query-based languages (regex in string arguments, no injection needed)
  local query_langs = {
    { 'python', 'python' },
    { 'go', 'go' },
    { 'rust', 'rust' },
    { 'php', 'php' },
    { 'java', 'java' },
    { 'c_sharp', 'cs' },
  }

  for _, entry in ipairs(query_langs) do
    local parser_lang, filetype = entry[1], entry[2]

    if not ensure_parser(parser_lang) then
      vim.health.info(filetype .. ': parser not available (skipped)')
    else
      local query_ok, query = pcall(vim.treesitter.query.get, parser_lang, 'regexplainer')
      if query_ok and query then
        vim.health.ok(filetype .. ': regexplainer query loaded')
      elseif not query_ok then
        vim.health.warn(filetype .. ': could not load query (' .. tostring(query) .. ')')
      else
        vim.health.error(filetype .. ': regexplainer query not found', {
          'Ensure nvim-regexplainer is up to date',
        })
      end
    end
  end

  vim.health.start('regexplainer: graphical mode')

  local graphics = require 'regexplainer.graphics'
  if graphics.is_graphics_supported() then
    local protocols = graphics.get_available_protocols()
    vim.health.ok(string.format('Graphics protocol available: %s', table.concat(protocols, ', ')))
  else
    vim.health.warn('No graphics protocol available', {
      'Graphical mode requires Kitty terminal',
      'Narrative mode will be used as fallback',
    })
  end

  local deps = require 'regexplainer.deps'
  local status = deps.check_health()

  if status.python_found then
    vim.health.ok(string.format('Python found: %s', status.python_version or 'unknown version'))
  else
    vim.health.warn('Python not found', {
      'Python 3.9+ is required for graphical mode',
      'Install Python from https://python.org',
    })
  end

  if status.venv_exists then
    vim.health.ok(string.format('Virtual environment exists: %s', status.venv_path))
  else
    vim.health.info(string.format('Virtual environment not found: %s', status.venv_path))
    vim.health.info('Virtual environment will be created automatically when needed')
  end

  if status.packages_available then
    vim.health.ok('All required Python packages are available')
  else
    if #status.missing_packages > 0 then
      vim.health.warn(string.format('Missing Python packages: %s', table.concat(status.missing_packages, ', ')), {
        'Packages will be installed automatically when graphical mode is used',
        'Or manually install with: pip install railroad-diagrams Pillow cairosvg',
      })
    else
      vim.health.info('Python packages not checked (Python not found)')
    end
  end
end

return M