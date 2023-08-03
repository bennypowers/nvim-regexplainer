SHELL:=/usr/bin/env bash
.PHONY: test run_tests watch ci unload

clean:
	@rm -rf vendor

watch:
	@echo "Testing..."
	@find . \
		-type f \
		-name '*.lua' \
		-o -name '*.js' \
		! -path "./.tests/**/*" | entr -d make run_tests

test:
	@REGEXPLAINER_DEBOUNCE=false \
		nvim \
			--headless \
			--noplugin \
			-u tests/mininit.lua \
			-c "lua require'plenary.test_harness'.test_directory('tests/regexplainer/', {minimal_init='tests/mininit.lua',sequential=true})"\
			-c "qa!"
