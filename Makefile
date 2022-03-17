clean:
	@rm -rf vendor/plenary.nvim
	@rm -rf vendor/nvim-treesitter
	@rm -rf vendor/nui.nvim

.PHONY: prepare test watch ci

test:
	@REGEXPLAINER_DEBOUNCE=false nvim \
		--headless \
		-u tests/mininit.lua \
		-c "PlenaryBustedDirectory tests/regexplainer { minimal_init = 'tests/mininit.lua' }" \
	  -c "qa!"

watch: prepare
	@echo "Testing..."
	@find . -type f -name '*.lua' ! -path "./vendor/**/*" | entr -d make test

ci:
	@nvim \
		--noplugin \
		-u tests/mininit.lua \
		-c "TSUpdateSync typescript regex" \
		-c "qa!"
	@make test
