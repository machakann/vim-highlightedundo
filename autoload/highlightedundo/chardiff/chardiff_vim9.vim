vim9script
scriptencoding utf-8

export def Diff(before: string, after: string, limit=255): list<list<list<number>>>
  if before ==# after
    return []
  endif
  if before[: limit] ==# after[: limit]
    # There is a difference after `limit` bytes.
    return [[[1, strlen(before)], [1, strlen(after)]]]
  endif
  var changelist = DiffImpl(before, after, limit)
  # Convert charidx to byteidx
  map(changelist, (k, v): list<list<number>> => [Byteidx(v[0], before), Byteidx(v[1], after)])
  return changelist
enddef


def Byteidx(order: list<number>, str: string): list<number>
  const idx = order[0] - 1
  const len = order[1]
  const byte_idx = byteidx(str, idx)
  const byte_len = byteidx(str, idx + len) - byte_idx
  return [byte_idx + 1, byte_len]
enddef


def DiffImpl(before: string, after: string, limit: number): list<list<list<number>>>
  const beforelen = strchars(before)
  const afterlen = strchars(after)
  if before ==# after
    return [[[1, beforelen], [1, afterlen]]]
  endif
  const chunklen = 3
  if min([beforelen, afterlen]) <= chunklen
    return CompareShort(before, after)
  endif
  return Compare(before, after, limit, chunklen)
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


def CompareShort(str1: string, str2: string): list<list<list<number>>>
  if strchars(str1) <= strchars(str2)
    return CompareShortImpl(str1, str2)
  endif
  return map(CompareShortImpl(str2, str1), 'reverse(v:val)')
enddef


def CompareShortImpl(short: string, long: string): list<list<list<number>>>
  const shortlen = strchars(short)
  const longlen = strchars(long)
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


def Compare(before_orig: string, after_orig: string, limit: number,
            chunklen: number): list<list<list<number>>>
  var before = before_orig[: limit]
  var after = after_orig[: limit]
  # NOTE: beforelen != strchars(before_orig) and
  #       afterlen != strchars(after_orig) in this func
  const beforelen = strchars(before)
  const afterlen = strchars(after)
  const loffset = CountCoincidence(before, after, 0, 0)
  const i = loffset
  const j = loffset
  if i == beforelen
    const original_after_len = strchars(after_orig)
    return [[[loffset + 1, 0], [loffset + 1, original_after_len - loffset]]]
  elseif j == afterlen
    const original_before_len = strchars(before_orig)
    return [[[loffset + 1, original_before_len - loffset], [loffset + 1, 0]]]
  endif

  const roffset = min([
    CountCoincidence(reverse(before), reverse(after), 0, 0),
    beforelen - loffset,
    afterlen - loffset,
  ])
  const imax = beforelen - roffset
  const jmax = afterlen - roffset
  final changelist: list<list<list<number>>> = []
  if i == imax
    add(changelist, [[loffset + 1, 0], [loffset + 1, afterlen - loffset - roffset]])
  elseif j == jmax
    add(changelist, [[loffset + 1, beforelen - loffset - roffset], [loffset + 1, 0]])
  else
    const d = CompareImpl(before[: imax - 1], after[: jmax - 1], chunklen, i, j, imax, jmax)
    extend(changelist, d)
  endif

  const before_rest = before_orig[limit + 1 :]
  const after_rest = after_orig[limit + 1 :]
  if before_rest ==# '' && after_rest !=# ''
    add(changelist, [[limit + 2, 0], [limit + 2, strchars(after_rest)]])
  elseif before_rest !=# '' && after_rest ==# ''
    add(changelist, [[limit + 2, strchars(before_rest)], [limit + 2, 0]])
  elseif before_rest !=# '' && after_rest !=# ''
    add(changelist, [[limit + 2, strchars(before_rest)], [limit + 2, strchars(after_rest)]])
  endif
  return changelist
enddef


def CompareImpl(before: string, after: string, chunklen: number, i0: number, j0: number,
                imax: number, jmax: number): list<list<list<number>>>
  var i = i0
  var j = j0
  var loop = 0
  const loopmax = 100
  final result: list<list<list<number>>> = []
  while loop < loopmax
    loop += 1
    var [ii, jj, k] = ChunkMatch(before, after, chunklen, i, j)
    if jj < 0
      # No match
      add(result, [[i + 1, imax - i], [j + 1, jmax - j]])
      break
    elseif jj == j
      if ii > i
        add(result, [[i + 1, ii - i], [j + 1, 0]])
      endif
    else
      if ii > i
        add(result, [[i + 1, ii - i], [j + 1, jj - j]])
      else
        add(result, [[i + 1, 0], [j + 1, jj - j]])
      endif
    endif
    i = ii + k
    j = jj + k
    if i > imax - chunklen || j > jmax - chunklen
      var del = [i + 1, max([imax - i, 0])]
      var add = [j + 1, max([jmax - j, 0])]
      if add[1] > 0 || del[1] > 0
        add(result, [del, add])
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
    var chunk = strpart(A, ii, chunklen)
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
