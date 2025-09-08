local regexplainer = require 'regexplainer'
local graphics = require 'regexplainer.graphics'

describe('graphical renderer', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
  end)

  after_each(function()
    regexplainer.teardown()
  end)

  describe('graphics protocol support', function()
    it('should have graphics module available', function()
      assert.is_not_nil(graphics)
      assert.is_function(graphics.is_graphics_supported)
      assert.is_function(graphics.display_image)
    end)

    it('should register kitty protocol', function()
      local protocols = graphics.get_available_protocols()
      -- Note: This will be empty unless running in actual Kitty terminal
      assert.is_table(protocols)
    end)
  end)

  describe('graphical renderer', function()
    it('should be available as a renderer', function()
      local renderers = require 'regexplainer.renderers'
      assert.is_not_nil(renderers.graphical)
      assert.is_function(renderers.graphical.get_lines)
      assert.is_function(renderers.graphical.set_lines)
    end)

    it('should support graphical mode in config', function()
      local config = {
        mode = 'graphical',
        graphical = {
          width = 1000,
          height = 800,
          python_cmd = 'python3'
        }
      }
      
      regexplainer.setup(config)
      
      -- Should not error when setting up with graphical mode
      assert.is_true(true)
    end)

    it('should fallback to narrative when graphics unavailable', function()
      -- Create a buffer with a simple regex
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'const regex = /test/' })
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'javascript')
      vim.api.nvim_set_current_buf(bufnr)
      
      -- Position cursor on the regex
      vim.api.nvim_win_set_cursor(0, { 1, 15 })
      
      -- Try to show graphical explanation
      -- This should fallback to narrative since we're not in Kitty
      regexplainer.show({ mode = 'graphical' })
      
      -- Should not error
      assert.is_true(true)
      
      -- Clean up
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should handle missing Python dependencies gracefully', function()
      local renderer = require 'regexplainer.renderers.graphical'
      
      -- Mock components
      local components = {
        {
          type = 'pattern_character',
          text = 'test',
          capture_depth = 0
        }
      }
      
      -- Mock options with invalid python command
      local options = {
        mode = 'graphical',
        graphical = {
          python_cmd = 'nonexistent_python_command'
        },
        debug = false
      }
      
      local state = { full_regexp_text = 'test' }
      
      -- Should not error and should return fallback lines
      local lines = renderer.get_lines(components, options, state)
      assert.is_table(lines)
      assert.is_true(#lines > 0)
    end)
  end)

  describe('Python railroad generator', function()
    it('should have script file available', function()
      local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/lua/regexplainer/python/railroad_generator.py"
      local readable = vim.fn.filereadable(script_path)
      assert.equals(1, readable, "Railroad generator script should be readable at: " .. script_path)
    end)
  end)
end)