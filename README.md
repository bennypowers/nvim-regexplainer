# nvim-regexplainer

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/bennypowers/nvim-regexplainer/main?style=for-the-badge)

Describe the regular expression under the cursor.

[![asciicast](https://asciinema.org/a/maz66tjNhpKgdwPOdTPV4CWJo.svg)](https://asciinema.org/a/maz66tjNhpKgdwPOdTPV4CWJo)

Heavily inspired by the venerable [atom-regexp-railroad](https://github.com/klorenz/atom-regex-railroad-diagrams/).

## 🚚 Installation

```lua
use { 'bennypowers/nvim-regexplainer',
      config = function() require'regexplainer'.setup()  end,
      requires = {
        'nvim-lua/plenary.nvim',
        'MunifTanjim/nui.nvim',
      } }
```

## 🤔 Config

```lua
-- defaults
require'regexplainer'.setup {
  -- 'narrative'
  mode = 'narrative', -- TODO: 'ascii', 'graphical'

  -- automatically show the explainer when the cursor enters a regexp
  auto = false,

  -- 'split', 'popup'
  display = 'popup',

  mappings = {
    show = 'gR',
  },

  narrative = {
    separator = '\n',
  },
}
```

### `display`
Set to `split` to display the explainer in a window below the editor.
The window will be reused, and has the filetype `Regexplainer`

Set to `popup` (the default) to display the explainer in a popup below the cursor.
When the cursor moves, the popup closes.

You can call `show` with your own display type to override your config

```lua
require'regexplainer'.show { display = 'split' }
```

Or use the commands `RegexplainerShowSplit` or `RegexplainerShowPopup`

### Render Options

`narrative.separator` can also be a function taking the current component and
returning a string clause separator. For example, to separate clauses by a new line, 
followed by `> ` for each level of capture-group depth, define the following
function:

```lua
narrative = {
  separator = function(component)
    local sep = '\n';
    if component.depth > 0 then
      for _ = 1, component.depth do
        sep = sep .. '> '
      end
    end
    return sep
  end
},
```

Input: 
```js
/zero(one(two(three)))/;
```

Output: 

`zero`  
capture group 1:  
> `one`  
> capture group 2:  
> > `two`  
> > capture group 3:  
> > > `three`

## 🗃️  TODO list
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  using ASCII-art
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  via [hologram](https://github.com/edluffy/hologram.nvim)
  and [kitty image protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- [ ] online documentation
- [ ] some unit tests or something, i guess


