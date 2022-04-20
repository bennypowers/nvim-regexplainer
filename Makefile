clean:
	@rm -rf vendor/plenary.nvim
	@rm -rf vendor/nvim-treesitter
	@rm -rf vendor/nui.nvim

.PHONY: test run_tests watch ci unload

unload:
	@pgrep -f 'nvim --headless' | xargs kill -s KILL

run_tests:
	@REGEXPLAINER_DEBOUNCE=false \
		nvim \
		--headless \
		-u tests/mininit.lua \
		-c "PlenaryBustedDirectory tests/regexplainer { minimal_init = 'tests/mininit.lua' }" \
	  -c "qa!"

test: unload
	@make run_tests

watch:
	@echo "Testing..."
	@find . \
		-type f \
		-name '*.lua' \
		-o -name '*.js' \
		! -path "./vendor/**/*" | entr -d make test

ci:
	@nvim --version
	@nvim \
		--headless \
		--noplugin \
		-u tests/mininit.lua \
		-c "TSUpdateSync javascript typescript regex" \
		-c "qa!"
	@make run_tests
