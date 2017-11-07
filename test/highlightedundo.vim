let s:suite = themis#suite('highlightedundo: ')
let s:scope = themis#helper('scope')
let s:highlightedundo = s:scope.funcs('autoload/highlightedundo.vim')

function! s:suite.before_each() abort "{{{
  new
endfunction
"}}}
function! s:suite.after_each() abort "{{{
  bwipeout!
endfunction "}}}
function! s:suite.after() abort "{{{
  call s:suite.before_each()
endfunction
"}}}

" undo
function! s:suite.undo_redo() abort "{{{
  normal! Afoo
  normal u
  call g:assert.equals(getline('.'), '', '#1')

  execute "normal \<C-r>"
  call g:assert.equals(getline('.'), 'foo', '#2')

  normal! Abar
  normal u
  call g:assert.equals(getline('.'), 'foo', '#3')

  execute "normal \<C-r>"
  call g:assert.equals(getline('.'), 'foobar', '#4')

  normal u
  call g:assert.equals(getline('.'), 'foo', '#5')

  normal! Abaz
  normal u
  call g:assert.equals(getline('.'), 'foo', '#6')

  execute "normal \<C-r>"
  call g:assert.equals(getline('.'), 'foobaz', '#7')

  execute "normal \<C-r>"
  call g:assert.equals(getline('.'), 'foobaz', '#8')

  normal u
  call g:assert.equals(getline('.'), 'foo', '#9')

  normal u
  call g:assert.equals(getline('.'), '', '#10')

  normal u
  call g:assert.equals(getline('.'), '', '#11')

  execute "normal 2\<C-r>"
  call g:assert.equals(getline('.'), 'foobaz', '#12')

  normal 2u
  call g:assert.equals(getline('.'), '', '#13')

  execute "normal 3\<C-r>"
  call g:assert.equals(getline('.'), 'foobaz', '#14')

  normal 3u
  call g:assert.equals(getline('.'), '', '#15')

  execute "normal! 3\<C-r>"
  normal! Aqux
  normal 2u
  call g:assert.equals(getline('.'), 'foo', '#16')

  normal! u
  execute "normal 2\<C-r>"
  call g:assert.equals(getline('.'), 'foobaz', '#17')
endfunction "}}}
" function! s:suite.gplus_gminus() abort "{{{
"   normal! Afoo
"   normal! Abar
"   normal! u
"   normal! Abaz

"   normal g-
"   call g:assert.equals(getline('.'), 'foobar', '#1')

"   normal g-
"   call g:assert.equals(getline('.'), 'foo', '#2')

"   normal g-
"   call g:assert.equals(getline('.'), '', '#3')

"   normal g+
"   call g:assert.equals(getline('.'), 'foo', '#4')

"   normal g+
"   call g:assert.equals(getline('.'), 'foobar', '#5')

"   normal g+
"   call g:assert.equals(getline('.'), 'foobaz', '#6')

"   normal 3g-
"   call g:assert.equals(getline('.'), '', '#7')

"   normal 3g+
"   call g:assert.equals(getline('.'), 'foobaz', '#8')

"   normal 2g-
"   call g:assert.equals(getline('.'), 'foo', '#9')

"   normal! g-
"   normal 2g+
"   call g:assert.equals(getline('.'), 'foobar', '#10')

"   normal! g+
"   normal 4g-
"   call g:assert.equals(getline('.'), '', '#11')

"   normal 4g+
"   call g:assert.equals(getline('.'), 'foobaz', '#12')
" endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
