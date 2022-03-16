---@class RegexplainerRenderer
---@field get_lines  "fun(components: RegexplainerComponent[], options: RegexplainerOptions): string[]"
---@field set_lines  "fun(buffer: NuiBuffer, lines: string[]): nil"SetLinesMethod

---@class RegexplainerRendererState
---@field full_regexp_text string  # caches the full regexp text.

---@type table<string, RegexplainerRenderer>
local M = {}

M.narrative = require'regexplainer.renderers.narrative'

return M
