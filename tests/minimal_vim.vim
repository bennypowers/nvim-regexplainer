set rtp+=.
set rtp+=vendor/plenary.nvim

runtime! plugin/plenary.vim
runtime! plugin/luapad.vim

lua require'plenary.busted'
