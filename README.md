# nvim-regexplainer

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/bennypowers/nvim-regexplainer/main?style=for-the-badge)

Describe the regular expression under the cursor.

https://user-images.githubusercontent.com/1466420/156946492-a05600dc-0a5b-49e6-9ad2-417a403909a8.mov

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

  -- Whether to log debug messages
  debug = false, 

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
When the cursor moves, the popup closes. if `auto` is set, the popup will automatically display
whenever the cursor moves inside a regular expression

You can call `show` with your own display type to override your config

```lua
require'regexplainer'.show { display = 'split' }
```

Or use the commands `RegexplainerShowSplit` or `RegexplainerShowPopup`.
`RegexplainerHide` is also available.

You can customize the popup window by specifying `options.popup.border`,
which is a table of [popup options from nui](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#border)
Currently, only `border` is supported, and any options specified override the defaults,
they are not merged with the default values.

```lua
require'regexplainer'.show {
  display = 'popup',
  popup = {
    border = {
      padding = { 1, 2 },
      style = 'solid',
    },
  },
}
```

You could use this to, for example, set a different border based on the state of your editor.

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
/zero(one(two(?<inner>three)))/;
```

Output: 

```md
`zero`  
capture group 1:  
> `one`  
> capture group 2:  
> > `two`  
> > named capture group 3 `inner`:  
> > > `three`
```

## 🗃️  TODO list
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  using ASCII-art
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  via [hologram](https://github.com/edluffy/hologram.nvim)
  and [kitty image protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- [ ] online documentation
- [ ] some unit tests or something, i guess


