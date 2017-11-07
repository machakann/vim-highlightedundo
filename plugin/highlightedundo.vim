" highlighted-yank: Make the undo region apparent!
" Last Change: 07-Nov-2017.
" Maintainer : Masaaki Nakamura <https://github.com/machakann/vim-highlightedundo>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if !executable('diff')
  echohl WarningMsg
  echomsg 'highlightedundo: "diff" command is necessary but it is not available.'
  echohl NONE
  finish
endif

if exists("g:loaded_highlightedundo")
  finish
endif
let g:loaded_highlightedundo = 1

nnoremap <silent> <Plug>(highlightedundo-undo)   :<C-u>call highlightedundo#undo()<CR>
nnoremap <silent> <Plug>(highlightedundo-redo)   :<C-u>call highlightedundo#redo()<CR>
nnoremap <silent> <Plug>(highlightedundo-Undo)   :<C-u>call highlightedundo#Undo()<CR>
nnoremap <silent> <Plug>(highlightedundo-gminus) :<C-u>call highlightedundo#gminus()<CR>
nnoremap <silent> <Plug>(highlightedundo-gplus)  :<C-u>call highlightedundo#gplus()<CR>

" highlight group
function! s:default_highlight() abort
  highlight default link HighlightedundoAdd DiffAdd
  highlight default link HighlightedundoDelete DiffDelete
  highlight default link HighlightedundoChange DiffChange
endfunction
call s:default_highlight()
augroup highlightedundo-event-ColorScheme
  autocmd!
  autocmd ColorScheme * call s:default_highlight()
augroup END
