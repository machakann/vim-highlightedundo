" Compare text line by line
let s:save_cpo = &cpoptions
set cpoptions&vim

if exists(':import') && v:version > 900
  import './chardiff/chardiff_vim9.vim' as chardiff
else
  let s:chardiff = highlightedundo#chardiff#chardiff_legacy#import()
endif

function! highlightedundo#chardiff#diff(before, after, ...) abort
  let limit = get(a:000, 0, 255)
  return s:chardiff.Diff(a:before, a:after, limit)
endfunction


function! highlightedundo#chardiff#similarity(before, after) abort
  return s:chardiff.Similarity(a:before, a:after)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2:
