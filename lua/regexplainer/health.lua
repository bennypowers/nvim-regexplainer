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
}

M.check = function()
  vim.health.start('regexplainer: dependencies')

  local nui_ok = pcall(require, 'nui')
  if nui_ok then
    vim.health.ok('nui.nvim is available')
  else
    vim.health.error('nui.nvim is not available', {
      'nvim-regexplainer requires nui.nvim',
      'Install it with your plugin manager',
    })
  end

  vim.health.start('regexplainer: treesitter')

  local parser_ok = pcall(vim.treesitter.language.add, 'regex')
  if parser_ok then
    vim.health.ok('regex parser is installed')
  else
    vim.health.error('regex parser is not installed', {
      'Install the regex parser for treesitter',
    })
  end

  for _, sample in ipairs(injection_samples) do
    local filetype, source, row, col = sample[1], sample[2], sample[3], sample[4]

    local lang_ok = pcall(vim.treesitter.language.add, filetype)
    if not lang_ok then
      vim.health.warn(filetype .. ': parser not installed (skipped)')
    else
      if test_regex_injection(filetype, source, row, col) then
        vim.health.ok(filetype .. ': regex injection working')
      else
        vim.health.error(filetype .. ': regex injection not detected', {
          'Ensure the ' .. filetype .. ' treesitter parser is up to date',
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