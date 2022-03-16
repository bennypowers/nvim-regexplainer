.PHONY: prepare test watch

clean:
	rm -rf vendor/plenary.nvim

prepare: clean
	@git clone https://github.com/nvim-lua/plenary.nvim vendor/plenary.nvim

test:
	@REGEXPLAINER_DEBOUNCE=false nvim \
		--headless \
		-u tests/mininit.lua \
		-c "PlenaryBustedDirectory tests/regexplainer { minimal_init = 'tests/mininit.lua' }"

watch: prepare
	@echo "Testing..."
	@find . -type f -name '*.lua' ! -path "./vendor/**/*" | entr -d make test
