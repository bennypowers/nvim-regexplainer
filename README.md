# nvim-regexp-railroad

![GitHub Workflow Status](https://img.shields.io/github/workflow/status/ellisonleao/nvim-plugin-template/default?style=for-the-badge)
![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
via [hologram](https://github.com/edluffy/hologram.nvim)
and [kitty image protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)

## 🚚 Installation

```lua
use { 'bennypowers/nvim-regexp-railroad',
      config = function() require'nvim-regexp-railroad'.setup()  end,
      requires = {
        'nvim-lua/plenary.nvim',
        'edluffy/hologram.nvim',
        'stevearc/dressing.nvim',
      } }
```

## 🤔 Config

```lua
-- defaults
require'nvim-regexp-railroad'.setup {
  mappings = {
    RegexpRailroadShow = 'gR',
  },
}
```
