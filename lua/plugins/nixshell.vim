" plugin/nixshell.vim
" Vim plugin file for nixshell.nvim

if exists('g:loaded_nixshell')
  finish
endif
let g:loaded_nixshell = 1

" Ensure Neovim
if !has('nvim')
  echohl WarningMsg
  echom "nixshell.nvim requires Neovim"
  echohl None
  finish
endif

" Auto-setup with default config if not manually called
augroup NixshellAutoSetup
  autocmd!
  autocmd VimEnter * ++once lua if not require('nixshell')._state.initialized then require('nixshell').setup() end
augroup END
