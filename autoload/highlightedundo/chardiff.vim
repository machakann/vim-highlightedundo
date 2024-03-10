" Compare text line by line
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:FALSE = 0
let s:TRUE = 1

function! highlightedundo#chardiff#diff(before, after, ...) abort
  if a:before ==# a:after
    return []
  endif
  let strlen_limit = get(a:000, 0, 255)
  let before = a:before[:strlen_limit]
  let after = a:after[:strlen_limit]
  let beforelen = strlen(before)
  let afterlen = strlen(after)
  if before ==# after
    return [[[1, beforelen], [1, afterlen]]]
  endif
  let chunklen = 3
  if min([beforelen, afterlen]) <= chunklen
    return s:compare_short(before, after)
  endif
  return s:compare(before, after, chunklen)
endfunction


function! highlightedundo#chardiff#similarity(before, after) abort "{{{
  if a:before is# a:after
    return 1.0
  endif
  let beforelen = strlen(a:before)
  let afterlen = strlen(a:after)
  let chunklen = 3
  let forward_match_p = s:count_coincidence(a:before, a:after, 0, 0)
  let i = forward_match_p
  let j = forward_match_p
  let [_, _, chunk_match_p] = s:chunk_match(a:before, a:after, chunklen, i, j)
  return 1.0*(forward_match_p + chunk_match_p)/min([beforelen, afterlen])
endfunction "}}}


function! s:compare_short(str1, str2) abort
  if strlen(a:str1) <= strlen(a:str2)
    return s:compare_short_impl(a:str1, a:str2)
  endif
  return map(s:compare_short_impl(a:str2, a:str1), 'reverse(v:val)')
endfunction


function! s:compare_short_impl(short, long) abort
  let shortexpr = s:to_expr(a:short)
  let i = match(a:long, shortexpr)
  let shortlen = strlen(a:short)
  let longlen = strlen(a:long)
  if i < 0
    " abc, abde
    return [[[1, shortlen], [1, longlen]]]
  endif

  if i == 0
    " abc, abcv
    return [[[shortlen + 1, 0], [shortlen + 1, longlen - shortlen]]]
  elseif i == longlen - shortlen
    " abc, uabc
    return [[[1, 0], [1, longlen - shortlen]]]
  endif
  " abc, uabcv
  return [
  \ [[1, 0], [1, i]],
  \ [[shortlen + 1, 0], [i + shortlen + 1, longlen - shortlen - i]],
  \ ]
endfunction


function! s:compare(A, B, chunklen) abort
  if a:A ==# a:B
    return []
  endif

  let Alen = strlen(a:A)
  let Blen = strlen(a:B)
  let loffset = s:count_coincidence(a:A, a:B, 0, 0)
  let i = loffset
  let j = loffset
  if i == Alen
    return [[[loffset + 1, 0], [loffset + 1, Blen - loffset]]]
  elseif j == Blen
    return [[[loffset + 1, Alen - loffset], [loffset + 1, 0]]]
  endif

  let roffset = s:count_coincidence(reverse(a:A), reverse(a:B), 0, 0)
  let roffset = min([roffset, Alen - loffset, Blen - loffset])
  let imax = Alen - roffset
  let jmax = Blen - roffset
  if i == imax
    return [[[loffset + 1, 0], [loffset + 1, Blen - loffset - roffset]]]
  elseif j == jmax
    return [[[loffset + 1, Alen - loffset - roffset], [loffset + 1, 0]]]
  endif
  return s:compare_impl(a:A[:imax - 1], a:B[:jmax - 1], a:chunklen, i, j, imax, jmax)
endfunction


function! s:compare_impl(A, B, chunklen, i0, j0, imax, jmax) abort
  let i = a:i0
  let j = a:j0
  let loop = 0
  let loopmax = 100
  let result = []
  while loop < loopmax
    let loop += 1
    let [ii, jj, k] = s:chunk_match(a:A, a:B, a:chunklen, i, j)
    if jj < 0
      " No match
      call add(result, [[i + 1, a:imax - i], [j + 1, a:jmax - j]])
      break
    elseif jj == j
      if ii > i
        call add(result, [[i + 1, ii - i], [j + 1, 0]])
      endif
    else
      if ii > i
        call add(result, [[i + 1, ii - i], [j + 1, jj - j]])
      else
        call add(result, [[i + 1, 0], [j + 1, jj - j]])
      endif
    endif
    let i = ii + k
    let j = jj + k
    if i > a:imax - a:chunklen || j > a:jmax - a:chunklen
      let del = [i + 1, max([a:imax - i, 0])]
      let add = [j + 1, max([a:jmax - j, 0])]
      if add[1] > 0 || del[1] > 0
        call add(result, [del, add])
      endif
      break
    endif
  endwhile
  return result
endfunction


function! s:chunk_match(A, B, chunklen, i0, j0) abort
  let Alen = strlen(a:A)
  let Blen = strlen(a:B)
  let i = Alen - a:chunklen - 1
  let j = -1
  if Alen - a:i0 < a:chunklen || Blen - a:j0 < a:chunklen
    return [i, j, 0]
  endif

  let k = 0
  let slip = a:chunklen*3
  for ii in range(a:i0, Alen - a:chunklen)
    let start = ii
    let end = ii + a:chunklen - 1
    let chunk = a:A[start:end]
    let chunkexpr = s:to_expr(chunk)
    let jj = match(a:B, chunkexpr, a:j0)
    if jj >= 0
      let kk = s:count_coincidence(a:A, a:B, ii, jj)
      if kk > k
        let [i, j, k] = [ii, jj, kk]
      endif
      let slip -= 1
    endif
    if slip <= 0
      break
    endif
  endfor
  return [i, j, k]
endfunction


function! s:to_expr(str) abort
  return '\C' . escape(a:str, '~"\.^$[]*')
endfunction


function! s:count_coincidence(A, B, i, j) abort
  let Alen = strlen(a:A)
  let Blen = strlen(a:B)
  let n = min([Alen - a:i, Blen - a:j])
  if n <= 0
    return 0
  endif

  for k in range(n)
    if a:A[a:i + k] !=# a:B[a:j + k]
      return k
    endif
  endfor
  return n
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
