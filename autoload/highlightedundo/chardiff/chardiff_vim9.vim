vim9script
scriptencoding utf-8

export def Diff(before: string, after: string, limit=255): list<list<list<number>>>
  if before ==# after
    return []
  endif
  var difflist = DiffImpl(before[: limit], after[: limit])
  # Convert charidx to byteidx
  map(difflist, (k, v): list<list<number>> => [Byteidx(v[0], before), Byteidx(v[1], after)])
  return difflist
enddef


def Byteidx(diff: list<number>, str: string): list<number>
  const idx = diff[0] - 1
  const len = diff[1]
  const byte_idx = byteidx(str, idx)
  const byte_len = byteidx(str, idx + len) - byte_idx
  return [byte_idx + 1, byte_len]
enddef


def DiffImpl(before: string, after: string): list<list<list<number>>>
  const beforelen = strchars(before)
  const afterlen = strchars(after)
  if before ==# after
    return [[[1, beforelen], [1, afterlen]]]
  endif
  const chunklen = 3
  if min([beforelen, afterlen]) <= chunklen
    return CompareShort(before, after, beforelen, afterlen)
  endif
  return Compare(before, after, beforelen, afterlen, chunklen)
enddef


export def Similarity(before: string, after: string): float
  if before ==# after
    return 1.0
  endif
  const beforelen = strchars(before)
  const afterlen = strchars(after)
  const chunklen = 3
  const forward_match_p = CountCoincidence(before, after, 0, 0)
  const i = forward_match_p
  const j = forward_match_p
  const [_, _, chunk_match_p] = ChunkMatch(before, after, chunklen, i, j)
  return 1.0 * (forward_match_p + chunk_match_p) / min([beforelen, afterlen])
enddef


def CompareShort(str1: string, str2: string, len1: number, len2: number): list<list<list<number>>>
  if len1 <= len2
    return CompareShortImpl(str1, str2, len1, len2)
  endif
  return map(CompareShortImpl(str2, str1, len2, len1), 'reverse(v:val)')
enddef


def CompareShortImpl(short: string, long: string, shortlen: number, longlen: number): list<list<list<number>>>
  const shortexpr = ToExpr(short)
  const i = Charmatch(long, shortexpr)
  if i < 0
    # abc, abde
    return [[[1, shortlen], [1, longlen]]]
  endif

  if i == 0
    # abc, abcv
    return [[[shortlen + 1, 0], [shortlen + 1, longlen - shortlen]]]
  elseif i == longlen - shortlen
    # abc, uabc
    return [[[1, 0], [1, longlen - shortlen]]]
  endif
  # abc, uabcv
  return [
    [[1, 0], [1, i]],
    [[shortlen + 1, 0], [i + shortlen + 1, longlen - shortlen - i]],
  ]
enddef


def Compare(A: string, B: string, Alen: number, Blen: number, chunklen: number): list<list<list<number>>>
  if A ==# B
    return []
  endif

  const loffset = CountCoincidence(A, B, 0, 0)
  const i = loffset
  const j = loffset
  if i == Alen
    return [[[loffset + 1, 0], [loffset + 1, Blen - loffset]]]
  elseif j == Blen
    return [[[loffset + 1, Alen - loffset], [loffset + 1, 0]]]
  endif

  const roffset = min([
    CountCoincidence(reverse(A), reverse(B), 0, 0),
    Alen - loffset,
    Blen - loffset,
  ])
  const imax = Alen - roffset
  const jmax = Blen - roffset
  if i == imax
    return [[[loffset + 1, 0], [loffset + 1, Blen - loffset - roffset]]]
  elseif j == jmax
    return [[[loffset + 1, Alen - loffset - roffset], [loffset + 1, 0]]]
  endif
  return CompareImpl(A[: imax - 1], B[: jmax - 1], chunklen, i, j, imax, jmax)
enddef


def CompareImpl(A: string, B: string, chunklen: number, i0: number, j0: number,
                imax: number, jmax: number): list<list<list<number>>>
  var i = i0
  var j = j0
  var loop = 0
  const loopmax = 100
  final result: list<list<list<number>>> = []
  while loop < loopmax
    loop += 1
    var [ii, jj, k] = ChunkMatch(A, B, chunklen, i, j)
    if jj < 0
      # No match
      call add(result, [[i + 1, imax - i], [j + 1, jmax - j]])
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
    i = ii + k
    j = jj + k
    if i > imax - chunklen || j > jmax - chunklen
      var del = [i + 1, max([imax - i, 0])]
      var add = [j + 1, max([jmax - j, 0])]
      if add[1] > 0 || del[1] > 0
        call add(result, [del, add])
      endif
      break
    endif
  endwhile
  return result
enddef


def ChunkMatch(A: string, B: string, chunklen: number, i0: number, j0: number): list<number>
  const Alen = strchars(A)
  const Blen = strchars(B)
  var i = Alen - chunklen - 1
  var j = -1
  if Alen - i0 < chunklen || Blen - j0 < chunklen
    return [i, j, 0]
  endif

  var k = 0
  var slip = chunklen * 3
  for ii in range(i0, Alen - chunklen)
    var start = ii
    var end = ii + chunklen - 1
    var chunk = A[start : end]
    var chunkexpr = ToExpr(chunk)
    var jj = Charmatch(B, chunkexpr, j0)
    if jj >= 0
      var kk = CountCoincidence(A, B, ii, jj)
      if kk > k
        [i, j, k] = [ii, jj, kk]
      endif
      slip -= 1
    endif
    if slip <= 0
      break
    endif
  endfor
  return [i, j, k]
enddef


def ToExpr(str: string): string
  return '\C' .. escape(str, '~"\.^$[]*')
enddef


def Charmatch(str: string, expr: string, start: number = 0): number
  return charidx(str, match(str, expr, byteidx(str, start)))
enddef


def CountCoincidence(A: string, B: string, i: number, j: number): number
  const Alen = strchars(A)
  const Blen = strchars(B)
  const n = min([Alen - i, Blen - j])
  if n <= 0
    return 0
  endif

  for k in range(n)
    if A[i + k] !=# B[j + k]
      return k
    endif
  endfor
  return n
enddef


defcompile

# vim:set ts=2 sts=2 sw=2:
