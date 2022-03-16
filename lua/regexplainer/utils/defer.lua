-- @license MIT hey@runiq.de
--

local M = {}

---Validates args for `throttle()` and  `debounce()`.
local function td_validate(fn, ms)
	vim.validate{
		fn = { fn, 'f' },
		ms = {
			ms,
			function(_ms)
				return type(_ms) == 'number' and _ms > 0
			end,
			"number > 0",
		},
	}
end

--- Debounces a function on the trailing edge. Automatically
--- `schedule_wrap()`s.
---
---@generic T              # function
---@param   fn T           # Function to debounce
---@param   ms number      # Timeout in ms
---@param   first? boolean # Whether to use the arguments of the first call to `fn` within the timeframe. Default: Use arguments of the last call.
---@returns T, Timer       # Debounced function and timer. Remember to call `timer:close()` at the end or you will leak memory!
function M.debounce_trailing(fn, ms, first)
	td_validate(fn, ms)
	local timer = vim.loop.new_timer()
	local wrapped_fn

	if not first then
		function wrapped_fn(...)
			local argv = {...}
			local argc = select('#', ...)

			timer:start(ms, 0, function()
				pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
			end)
		end
	else
		local argv, argc
		function wrapped_fn(...)
			argv = argv or {...}
			argc = argc or select('#', ...)

			timer:start(ms, 0, function()
				pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
			end)
		end
	end
	return wrapped_fn, timer
end

return M
