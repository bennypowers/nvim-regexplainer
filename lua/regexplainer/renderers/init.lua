---@class RegexplainerRenderer
---@field get_lines  fun(components:RegexplainerComponent[],options:RegexplainerOptions,state?:RegexplainerRendererState):string[]
---@field set_lines  fun(buffer:RegexplainerBuffer,lines:string[]):nil

---@class RegexplainerRendererState
---@field full_regexp_text string  # caches the full regexp text.
---@field last? RegexplainerBuffer

---@type table<string, RegexplainerRenderer>
local M = {}

M.narrative = require 'regexplainer.renderers.narrative'

return M
