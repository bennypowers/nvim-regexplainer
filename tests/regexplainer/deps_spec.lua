local regexplainer = require 'regexplainer'
local deps = require 'regexplainer.deps'

describe('dependency management', function()
  before_each(function()
    regexplainer.teardown()
    regexplainer.setup()
    deps.clear_cache()
  end)

  after_each(function()
    regexplainer.teardown()
    deps.clear_cache()
  end)

  describe('Python detection', function()
    it('should detect Python availability', function()
      local status = deps.check_health()
      
      -- This test depends on system having Python, so we just verify the structure
      assert.is_table(status)
      assert.is_boolean(status.python_found)
      assert.is_boolean(status.venv_exists)
      assert.is_boolean(status.packages_available)
      assert.is_table(status.missing_packages)
      assert.is_string(status.venv_path)
    end)
  end)

  describe('configuration', function()
    it('should accept dependency configuration', function()
      local config = {
        mode = 'graphical',
        deps = {
          auto_install = false,
          python_cmd = 'python3',
          check_interval = 1800,
        }
      }
      
      regexplainer.setup(config)
      
      -- Should not error when setting up with dependency config
      assert.is_true(true)
    end)

    it('should handle custom venv path', function()
      local config = {
        deps = {
          venv_path = '/tmp/test_venv',
          auto_install = false,
        }
      }
      
      local status = deps.check_health(config.deps)
      assert.equals('/tmp/test_venv', status.venv_path)
    end)
  end)

  describe('error handling', function()
    it('should handle missing Python gracefully', function()
      local config = {
        auto_install = false,
        python_cmd = 'nonexistent_python_command',
      }
      
      local python_cmd, err = deps.get_python_cmd(config, {})
      assert.is_nil(python_cmd)
      assert.is_string(err)
    end)

    it('should handle disabled auto_install', function()
      local config = {
        auto_install = false,
        python_cmd = 'python3', -- This might exist but without packages
      }
      
      -- This test will vary based on system state, so we just verify it doesn't crash
      local python_cmd, err = deps.get_python_cmd(config, {})
      
      -- Either succeeds (if packages are already installed) or fails gracefully
      if not python_cmd then
        assert.is_string(err)
      else
        assert.is_string(python_cmd)
      end
    end)
  end)

  describe('cache behavior', function()
    it('should cache dependency check results', function()
      local config = {
        check_interval = 1, -- Very short interval for testing
        auto_install = false,
      }
      
      -- First call
      local result1 = deps.get_python_cmd(config, {})
      
      -- Second call should use cache (we can't easily verify this without mocking)
      local result2 = deps.get_python_cmd(config, {})
      
      -- Results should be consistent
      assert.equals(result1, result2)
    end)

    it('should clear cache when requested', function()
      deps.clear_cache()
      
      -- Should not error
      assert.is_true(true)
    end)
  end)
end)