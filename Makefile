.PHONY: prepare test watch ci

clean:
	@rm -rf vendor/plenary.nvim
	@rm -rf vendor/nvim-treesitter
	@rm -rf vendor/nui.nvim

prepare: clean
	@git clone https://github.com/nvim-lua/plenary.nvim           vendor/plenary.nvim
	@git clone https://github.com/nvim-treesitter/nvim-treesitter vendor/nvim-treesitter
	@git clone https://github.com/MunifTanjim/nui.nvim/           vendor/nui.nvim

test:
	@REGEXPLAINER_DEBOUNCE=false nvim \
		--headless \
		-u tests/mininit.lua \
		-c "PlenaryBustedDirectory tests/regexplainer { minimal_init = 'tests/mininit.lua' }"

watch: prepare
	@echo "Testing..."
	@find . -type f -name '*.lua' ! -path "./vendor/**/*" | entr -d make test

ci:
	@nvim --noplugin -u tests/mininit.lua -c "TSUpdateSync org" -c "qa!"
	@make test
