SHELL:=/usr/bin/env bash
.PHONY: test run_tests watch ci unload

clean:
	@rm -rf vendor/plenary.nvim
	@rm -rf vendor/nvim-treesitter
	@rm -rf vendor/nui.nvim

unload:
	@pgrep -f 'nvim --headless' | xargs kill -s KILL;

run_tests:
	@REGEXPLAINER_DEBOUNCE=false \
		nvim \
		--headless \
		-u tests/mininit.lua \
		-c "PlenaryBustedDirectory tests/regexplainer { minimal_init = 'tests/mininit.lua' }" \
	  -c "qa!"

watch:
	@echo "Testing..."
	@find . \
		-type f \
		-name '*.lua' \
		-o -name '*.js' \
		! -path "./vendor/**/*" | entr -d make run_tests

test:
	@make unload
	@make run_tests

ci:
	@nvim --version
	@nvim \
		--headless \
		--noplugin \
		-u tests/mininit.lua \
		-c "TSUpdateSync javascript typescript regex" \
		-c "qa!"
	@make run_tests
