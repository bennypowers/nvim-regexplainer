---@class RegexplainerRenderer
---@field get_lines  "fun(components: RegexplainerComponent[], options: RegexplainerOptions): string[]"
---@field set_lines  "fun(buffer: NuiBuffer, lines: string[]): nil"SetLinesMethod

---@type table<string, RegexplainerRenderer>
local M = {}

M.narrative = require'regexplainer.renderers.narrative'

return M
