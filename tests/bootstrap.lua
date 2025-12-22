local Setup = require 'tests.setup'

Setup.load 'MunifTanjim/nui.nvim'
Setup.load 'nvim-lua/plenary.nvim'
Setup.load 'nvim-treesitter/nvim-treesitter'

Setup.setup()

local ts = require 'nvim-treesitter'
ts.install({
  'html',
  'javascript',
  'typescript',
  'regex',
}):wait(10000)
