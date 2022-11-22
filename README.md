# nvim-regexplainer

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/bennypowers/nvim-regexplainer/main?style=for-the-badge)

Describe the regular expression under the cursor.

https://user-images.githubusercontent.com/1466420/156946492-a05600dc-0a5b-49e6-9ad2-417a403909a8.mov

Heavily inspired by the venerable [atom-regexp-railroad](https://github.com/klorenz/atom-regex-railroad-diagrams/).

> 👉 **NOTE**: Requires Neovim 0.7 👈

## 🚚 Installation

```lua
use { 'bennypowers/nvim-regexplainer',
      config = function() require'regexplainer'.setup() end,
      requires = {
        'nvim-treesitter/nvim-treesitter',
        'MunifTanjim/nui.nvim',
      } }
```

You need to install `regex` with `nvim-treesitter`

```vimscript
:TSInstall regex
```

## 🤔 Config

```lua
-- defaults
require'regexplainer'.setup {
  -- 'narrative'
  mode = 'narrative', -- TODO: 'ascii', 'graphical'

  -- automatically show the explainer when the cursor enters a regexp
  auto = false,

  -- filetypes (i.e. extensions) in which to run the autocommand
  filetypes = {
    'html',
    'js',
    'cjs',
    'mjs',
    'ts',
    'jsx',
    'tsx',
    'cjsx',
    'mjsx',
  },

  -- Whether to log debug messages
  debug = false, 

  -- 'split', 'popup'
  display = 'popup',

  mappings = {
    toggle = 'gR',
    -- examples, not defaults:
    -- show = 'gS',
    -- hide = 'gH',
    -- show_split = 'gP',
    -- show_popup = 'gU',
  },

  narrative = {
    separator = '\n',
  },
}
```

### `display`

Regexplainer offers a small variety of display modes to suit your preferences.

#### Split Window

Set to `split` to display the explainer in a window below the editor.
The window will be reused, and has the filetype `Regexplainer`

#### Popup Below Cursor

Set to `popup` (the default) to display the explainer in a popup below the cursor.
When the cursor moves, the popup closes. if `auto` is set, the popup will automatically display
whenever the cursor moves inside a regular expression

You can call `show` with your own display type to override your config

```lua
require'regexplainer'.show { display = 'split' }
```

Or use the commands `RegexplainerShowSplit` or `RegexplainerShowPopup`.
`RegexplainerHide` and `RegexplainerToggle` are also available.

You can customize the popup window by specifying `options.popup.border`,
which is a table of [popup options from nui](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#border).
Any options specified for `options.popup` will also override the defaults.

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

## Yank
You can yank the regexplanation into any register with the `yank` function. The 
default register is `"`. This can be useful if you'd like to share the 
explanation of a regexp with your teammates, or if you'd like to report a 
mistake in regexplainer.
The argument to `yank` is either a string (the register to yank to) or a table 
with `register: string` and options to `show` (e.g. `mode = 'narrative', 
narrative = {}`, etc.).

For example, to copy the regexplanation to your system clipboard, use either of 
these:

```lua
require'regexplainer'.yank'+'
```

```lua
require'regexplainer'.yank { register = '+' }
```

You can also use the command `RegexplainerYank`

```vim
:RegexplainerYank +
```

## A Note about Lookbehinds

While https://github.com/tree-sitter/tree-sitter-regex/issues/13 is still open, lookbehind
support is partial, and results may not be accurate, especially if the term in the lookbehind
is complex, e.g. 

```js
/(?<!http|https:\/\/)www\.regex101\.com/;
```

## 🗃️  TODO list
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  using ASCII-art
- [ ] Display Regexp [railroad diagrams](https://github.com/tabatkins/railroad-diagrams/)
  via [hologram](https://github.com/edluffy/hologram.nvim)
  and [kitty image protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- [ ] online documentation
- [x] some unit tests or something, i guess


