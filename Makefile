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
		! -path "./.tests/**/*" | entr -d make test

test:
	@REGEXPLAINER_DEBOUNCE=false \
		nvim \
			--headless \
			--noplugin \
			-u tests/mininit.lua \
			-c "PlenaryBustedDirectory tests/regexplainer/ {minimal_init='tests/mininit.lua',sequential=true,keep_going=false}"\
			-c "qa!"
