let s:suite = themis#suite('highlightedundo: ')
let s:scope = themis#helper('scope')
let s:highlightedundo = s:scope.funcs('autoload/highlightedundo.vim')

if v:version > 900
  import '../autoload/highlightedundo/chardiff/chardiff_vim9.vim' as chardiff
endif


function! s:suite.before_each() abort
  new
  let g:highlightedundo#debounce = 1
endfunction


function! s:suite.after_each() abort
  bwipeout!
endfunction


function! s:suite.after() abort
  call s:suite.before_each()
endfunction


function! s:test_chardiff(chardiff) abort
  call g:assert.equals(
  \ a:chardiff('abc', 'abc'),
  \ [], '#1')

  call g:assert.equals(a:chardiff('abc', 'uabc'),
  \ [[[1, 0], [1, 1]]], '#2')

  call g:assert.equals(a:chardiff('abc', 'uuuabc'),
  \ [[[1, 0], [1, 3]]], '#3')

  call g:assert.equals(a:chardiff('uabc', 'abc'),
  \ [[[1, 1], [1, 0]]], '#4')

  call g:assert.equals(a:chardiff('uuuabc', 'abc'),
  \ [[[1, 3], [1, 0]]], '#5')

  call g:assert.equals(a:chardiff('abc', 'uabcv'),
  \ [[[1, 0], [1, 1]], [[4, 0], [5, 1]]], '#6')

  call g:assert.equals(a:chardiff('abc', 'uuuabcvvv'),
  \ [[[1, 0], [1, 3]], [[4, 0], [7, 3]]], '#7')

  call g:assert.equals(a:chardiff('uabcv', 'abc'),
  \ [[[1, 1], [1, 0]], [[5, 1], [4, 0]]], '#8')

  call g:assert.equals(a:chardiff('uuuabcvvv', 'abc'),
  \ [[[1, 3], [1, 0]], [[7, 3], [4, 0]]], '#9')

  call g:assert.equals(a:chardiff('abc', 'uab'),
  \ [[[1, 3], [1, 3]]], '#10')

  call g:assert.equals(a:chardiff('abc', 'abv'),
  \ [[[1, 3], [1, 3]]], '#11')

  call g:assert.equals(a:chardiff('abc', 'uabv'),
  \ [[[1, 3], [1, 4]]], '#12')

  call g:assert.equals(a:chardiff('uabv', 'abc'),
  \ [[[1, 4], [1, 3]]], '#13')

  call g:assert.equals(a:chardiff('abcuuu', 'abcuuu'),
  \ [], '#14')

  call g:assert.equals(a:chardiff('abcuuuuuu', 'uuuuuu'),
  \ [[[1, 3], [1, 0]]], '#15')

  call g:assert.equals(a:chardiff('uuuuuu', 'abcuuuuuu'),
  \ [[[1, 0], [1, 3]]], '#16')

  call g:assert.equals(a:chardiff('uuuabcuuu', 'uuuuuu'),
  \ [[[4, 3], [4, 0]]], '#17')

  call g:assert.equals(a:chardiff('uuuuuu', 'uuuabcuuu'),
  \ [[[4, 0], [4, 3]]], '#18')

  call g:assert.equals(a:chardiff('abcuuu', 'abcvvv'),
  \ [[[4, 3], [4, 3]]], '#19')

  call g:assert.equals(a:chardiff('uuuabc', 'vvvabc'),
  \ [[[1, 3], [1, 3]]], '#20')

  call g:assert.equals(a:chardiff('uuuabcvvv', 'wwwabcxxx'),
  \ [[[1, 3], [1, 3]], [[7, 3], [7, 3]]], '#21')

  call g:assert.equals(a:chardiff('uuabcvvvv', 'vvvabcuuu'),
  \ [[[1, 2], [1, 3]], [[6, 4], [7, 3]]], '#22')

  " There are several interpretations for this problem,
  " this might be flaky
  call g:assert.equals(a:chardiff('uuabcvv', 'vvabcuu'),
  \ [[[1, 2], [1, 2]], [[6, 2], [6, 2]]], '#23')

  call g:assert.equals(a:chardiff('uuuuu', 'uuu'),
  \ [[[4, 2], [4, 0]]], '#24')

  call g:assert.equals(a:chardiff('foo(bar)', 'foo(qux)'),
  \ [[[5, 3], [5, 3]]], '#25')

  call g:assert.equals(a:chardiff('foo(bar(qux), baz)', 'foo(qux, baz)'),
  \ [[[5, 4], [5, 0]], [[12, 1], [8, 0]]], '#26')

  call g:assert.equals(a:chardiff('foo(qux, baz)', 'foo(bar(qux), baz)'),
  \ [[[5, 0], [5, 4]], [[8, 0], [12, 1]]], '#27')

  call g:assert.equals(a:chardiff('foo(bar(A), B)', 'foo(A, B)'),
  \ [[[5, 6], [5, 1]]], '#28')

  call g:assert.equals(a:chardiff('foobarbaz(qux), foobarbaz(corge)', 'qux, foobarbaz(corge)'),
  \ [[[1, 10], [1, 0]], [[14, 1], [4, 0]]], '#29')
endfunction


function! s:test_undo_redo() abort
  normal! Afoo
  execute "normal! i\<C-g>u"
  normal u
  sleep 2m
  call g:assert.equals(getline('.'), '', '#1')

  execute "normal \<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#2')

  normal! Abar
  normal u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#3')

  execute "normal \<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobar', '#4')

  normal u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#5')

  normal! Abaz
  normal u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#6')

  execute "normal \<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#7')

  execute "normal \<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#8')

  normal u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#9')

  normal u
  sleep 2m
  call g:assert.equals(getline('.'), '', '#10')

  normal u
  sleep 2m
  call g:assert.equals(getline('.'), '', '#11')

  execute "normal 2\<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#12')

  normal 2u
  sleep 2m
  call g:assert.equals(getline('.'), '', '#13')

  execute "normal 3\<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#14')

  normal 3u
  sleep 2m
  call g:assert.equals(getline('.'), '', '#15')

  execute "normal! 3\<C-r>"
  normal! Aqux
  normal 2u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#16')

  normal! u
  execute "normal 2\<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#17')
endfunction


function! s:test_gplus_gminus() abort
  normal! Afoo
  execute "normal! i\<C-g>u"
  normal! Abar
  execute "normal! i\<C-g>u"
  normal! u
  normal! Abaz

  normal g-
  sleep 2m
  call g:assert.equals(getline('.'), 'foobar', '#1')

  normal g-
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#2')

  normal g-
  sleep 2m
  call g:assert.equals(getline('.'), '', '#3')

  normal g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#4')

  normal g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foobar', '#5')

  normal g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#6')

  normal 3g-
  sleep 2m
  call g:assert.equals(getline('.'), '', '#7')

  normal 3g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#8')

  normal 2g-
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#9')

  normal! g-
  normal 2g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foobar', '#10')

  normal! g+
  normal 4g-
  sleep 2m
  call g:assert.equals(getline('.'), '', '#11')

  normal 4g+
  sleep 2m
  call g:assert.equals(getline('.'), 'foobaz', '#12')
endfunction


function! s:test_reset_undolebels() abort
  normal! Afoo
  let old_undolevels = &undolevels
  set undolevels=-1
  exe "normal a \<BS>\<Esc>"
  let &undolevels = old_undolevels
  " undotree().entries should be empty now
  normal u
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#1')

  execute "normal \<C-r>"
  sleep 2m
  call g:assert.equals(getline('.'), 'foo', '#2')
endfunction




function! s:suite.chardiff_legacy() abort
  let chardiff = highlightedundo#chardiff#chardiff_legacy#import()
  call s:test_chardiff(chardiff.Diff)
endfunction


if v:version > 900
  function! s:suite.chardiff_vim9() abort
    call s:test_chardiff(s:chardiff.Diff)
  endfunction
endif


function! s:suite.diff() abort
  let before = ['abc']
  let after = ['abc']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [],
  \ '#1')

  let before = ['abc']
  let after = ['']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 0, 'from_count': 1, 'to_idx': 0, 'to_count': 1}],
  \ '#2')

  let before = ['']
  let after = ['abc']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 0, 'from_count': 1, 'to_idx': 0, 'to_count': 1}],
  \ '#3')

  let before = ['abc']
  let after = ['def']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 0, 'from_count': 1, 'to_idx': 0, 'to_count': 1}],
  \ '#4')

  let before = ['xxx', 'abc']
  let after = ['abc']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 0, 'from_count': 1, 'to_idx': 0, 'to_count': 0}],
  \ '#5')

  let before = ['abc', 'xxx']
  let after = ['abc']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 1, 'from_count': 1, 'to_idx': 1, 'to_count': 0}],
  \ '#6')

  let before = ['abc']
  let after = ['xxx', 'abc']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 0, 'from_count': 0, 'to_idx': 0, 'to_count': 1}],
  \ '#7')

  let before = ['abc']
  let after = ['abc', 'xxx']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 1, 'from_count': 0, 'to_idx': 1, 'to_count': 1}],
  \ '#8')

  let before = ['abc', 'xxx']
  let after = ['abc', 'yyy']
  call g:assert.equals(
  \ s:highlightedundo.diff(before, after),
  \ [{'from_idx': 1, 'from_count': 1, 'to_idx': 1, 'to_count': 1}],
  \ '#9')
endfunction


function! s:suite.parsediff() abort
  let before = ['abc']
  let after = ['abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [],
  \ '#1')

  let before = ['xxx', 'abc']
  let after = ['abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('d', [1]),
  \ ],
  \ '#2')

  let before = ['xxx', 'yyy', 'abc']
  let after = ['abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('d', [1]),
  \   s:highlightedundo.Diff('d', [2]),
  \ ],
  \ '#3')

  let before = ['abc', 'xxx', 'yyy']
  let after = ['abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('d', [2]),
  \   s:highlightedundo.Diff('d', [3]),
  \ ],
  \ '#4')

  let before = ['xxx', 'abc', 'yyy']
  let after = ['abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('d', [1]),
  \   s:highlightedundo.Diff('d', [3]),
  \ ],
  \ '#5')

  let before = ['abc']
  let after = ['xxx', 'abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \ ],
  \ '#6')

  let before = ['abc']
  let after = ['xxx', 'yyy', 'abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \   s:highlightedundo.Diff('a', [2]),
  \ ],
  \ '#7')

  let before = ['abc']
  let after = ['abc', 'xxx', 'yyy']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [2]),
  \   s:highlightedundo.Diff('a', [3]),
  \ ],
  \ '#8')

  let before = ['abc']
  let after = ['xxx', 'abc', 'yyy']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \   s:highlightedundo.Diff('a', [3]),
  \ ],
  \ '#9')

  let before = ['xxx', 'yyy', 'abc']
  let after = ['uuu', 'vvv', 'abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [1, 1, 3], [1, 1, 3]),
  \   s:highlightedundo.Diff('c', [2, 1, 3], [2, 1, 3]),
  \ ],
  \ '#10')

  let before = ['abc', 'xxx', 'yyy']
  let after = ['abc', 'uuu', 'vvv']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [2, 1, 3], [2, 1, 3]),
  \   s:highlightedundo.Diff('c', [3, 1, 3], [3, 1, 3]),
  \ ],
  \ '#11')

  let before = ['xxx', 'abc', 'yyy']
  let after = ['uuu', 'abc', 'vvv']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [1, 1, 3], [1, 1, 3]),
  \   s:highlightedundo.Diff('c', [3, 1, 3], [3, 1, 3]),
  \ ],
  \ '#12')

  let before = ['abc', 'xxx', 'yyy']
  let after = ['abc', 'vvv']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [2, 1, 3], [2, 1, 3]),
  \   s:highlightedundo.Diff('d', [3]),
  \ ],
  \ '#13')

  let before = ['xxx', 'yyy', 'abc']
  let after = ['vvv', 'abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [1, 1, 3], [1, 1, 3]),
  \   s:highlightedundo.Diff('d', [2]),
  \ ],
  \ '#14')

  let before = ['xxx', 'abc', 'yyy']
  let after = ['vvv', 'abc']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [1, 1, 3], [1, 1, 3]),
  \   s:highlightedundo.Diff('d', [3]),
  \ ],
  \ '#15')

  let before = ['abcd', 'xxx', 'yyy']
  let after = ['abce', 'vvv']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('c', [1, 4, 1], [1, 4, 1]),
  \   s:highlightedundo.Diff('c', [2, 1, 3], [2, 1, 3]),
  \   s:highlightedundo.Diff('d', [3]),
  \ ],
  \ '#16')

  let before = ['abce', 'vvv']
  let after = ['xxx', 'abcd', 'yyy']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \   s:highlightedundo.Diff('c', [1, 4, 1], [2, 4, 1]),
  \   s:highlightedundo.Diff('c', [2, 1, 3], [3, 1, 3]),
  \ ],
  \ '#17')

  let before = ['abcd', 'vvv']
  let after = ['xxx', 'yyy', 'abce']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \   s:highlightedundo.Diff('a', [2]),
  \   s:highlightedundo.Diff('c', [1, 4, 1], [3, 4, 1]),
  \   s:highlightedundo.Diff('d', [2]),
  \ ],
  \ '#18')

  let before = ['abcd']
  let after = ['xxx', 'abce', 'yyy']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1]),
  \   s:highlightedundo.Diff('c', [1, 4, 1], [2, 4, 1]),
  \   s:highlightedundo.Diff('a', [3]),
  \ ],
  \ '#19')

  let before = ['foobarbaz']
  let after = ['barbaz']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('d', [1, 1, 3]),
  \ ],
  \ '#20')

  let before = ['foobarbaz', 'foobarbaz']
  let after = ['foobarbazfoobarbaz']
  let hunks = s:highlightedundo.diff(before, after)
  call g:assert.equals(
  \ s:highlightedundo.parsediff(hunks, before, after),
  \ [
  \   s:highlightedundo.Diff('a', [1, 10, 9]),
  \   s:highlightedundo.Diff('d', [2]),
  \ ],
  \ '#21')



  let before = repeat(['foo bar baz'], 1000)
  let after = repeat(['foo bar qux'], 1000)
  let hunks = s:highlightedundo.diff(before, after)
  let result = s:highlightedundo.parsediff(hunks, before, after, [995, 999], [0, 4])
  let diff_kind  = copy(result)
                 \->map('v:val["kind"]')
  let highlight_lines_before = copy(result)
                             \->map('v:val["delete"]')
                             \->map('v:val[0]')
  let highlight_lines_after  = copy(result)
                             \->map('v:val["add"]')
                             \->map('v:val[0]')
  call g:assert.equals(diff_kind,
  \ ['c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c'], '#22')
  call g:assert.equals(highlight_lines_before,
  \ [1, 2, 3, 4, 5, 996, 997, 998, 999, 1000], '#23')
  call g:assert.equals(highlight_lines_after,
  \ [1, 2, 3, 4, 5, 996, 997, 998, 999, 1000], '#24')



  let before = ['uuu'] + repeat(['foo bar baz'], 1000)
  let after = repeat(['foo bar qux'], 1000)
  let hunks = s:highlightedundo.diff(before, after)
  let result = s:highlightedundo.parsediff(hunks, before, after, [0, 5], [995, 999])
  let diff_kind  = copy(result)
                \->map('v:val["kind"]')
  let highlight_lines_before = copy(result)
                            \->map('v:val["delete"]')
                            \->filter('v:val != []')
                            \->map('v:val[0]')
  let highlight_lines_after  = copy(result)
                            \->map('v:val["add"]')
                            \->filter('v:val != []')
                            \->map('v:val[0]')
  call g:assert.equals(diff_kind,
  \ ['d', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c'], '#25')
  call g:assert.equals(highlight_lines_before, [1, 2, 3, 4, 5, 6, 997, 998, 999, 1000, 1001], '#26')
  call g:assert.equals(highlight_lines_after, [1, 2, 3, 4, 5, 996, 997, 998, 999, 1000], '#27')



  let before = repeat(['foo bar baz'], 1000) + ['vvv']
  let after = repeat(['foo bar qux'], 1000)
  let hunks = s:highlightedundo.diff(before, after)
  let result = s:highlightedundo.parsediff(hunks, before, after, [996, 1000], [0, 4])
  let diff_kind  = copy(result)
                 \->map('v:val["kind"]')
  let highlight_lines_before = copy(result)
                             \->map('v:val["delete"]')
                             \->filter('v:val != []')
                             \->map('v:val[0]')
  let highlight_lines_after  = copy(result)
                             \->map('v:val["add"]')
                             \->filter('v:val != []')
                             \->map('v:val[0]')
  call g:assert.equals(diff_kind,
  \ ['c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'c', 'd'], '#28')
  call g:assert.equals(highlight_lines_before, [1, 2, 3, 4, 5, 997, 998, 999, 1000, 1001], '#29')
  call g:assert.equals(highlight_lines_after, [1, 2, 3, 4, 5, 997, 998, 999, 1000], '#30')
endfunction


function! s:suite.undo_redo_1step() abort
  let g:highlightedundo#highlight_mode = 1
  call s:test_undo_redo()
endfunction


function! s:suite.gplus_gminus_1step() abort
  let g:highlightedundo#highlight_mode = 1
  call s:test_gplus_gminus()
endfunction


function! s:suite.reset_undolebels_1step() abort
  let g:highlightedundo#highlight_mode = 1
  call s:test_reset_undolebels()
endfunction


function! s:suite.undo_redo_2step() abort
  let g:highlightedundo#highlight_mode = 2
  call s:test_undo_redo()
endfunction


function! s:suite.gplus_gminus_2step() abort
  let g:highlightedundo#highlight_mode = 2
  call s:test_gplus_gminus()
endfunction


function! s:suite.reset_undolebels_2step() abort
  let g:highlightedundo#highlight_mode = 2
  call s:test_reset_undolebels()
endfunction


" vim:set ts=2 sts=2 sw=2:
