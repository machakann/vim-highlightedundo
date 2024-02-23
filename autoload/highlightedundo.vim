let s:save_cpo = &cpoptions
set cpoptions&vim

let g:highlightedundo#highlight_mode = get(g:, 'highlightedundo#highlight_mode', 1)
let g:highlightedundo#highlight_duration_delete = get(g:, 'highlightedundo#highlight_duration_delete', 200)
let g:highlightedundo#highlight_duration_add = get(g:, 'highlightedundo#highlight_duration_add', 500)

let s:TEMPBEFORE = ''
let s:TEMPAFTER = ''
let s:GUI_RUNNING = has('gui_running')

function! highlightedundo#undo() abort "{{{
  let [n, _] = s:undoablecount()
  let safecount = min([v:count1, n])
  call s:common(safecount, 'u', "\<C-r>")
endfunction "}}}
function! highlightedundo#redo() abort "{{{
  let [_, n] = s:undoablecount()
  let safecount = min([v:count1, n])
  call s:common(safecount, "\<C-r>", 'u')
endfunction "}}}
function! highlightedundo#Undo() abort "{{{
  call s:common(1, 'U', 'U')
endfunction "}}}
function! highlightedundo#gminus() abort "{{{
  let undotree = undotree()
  let safecount = min([v:count1, undotree.seq_cur - 1])
  call s:common(safecount, 'g-', 'g+')
endfunction "}}}
function! highlightedundo#gplus() abort "{{{
  let undotree = undotree()
  let safecount = min([v:count1, undotree.seq_last - undotree.seq_cur])
  call s:common(safecount, 'g+', 'g-')
endfunction "}}}
function! s:common(count, command, countercommand) abort "{{{
  if a:count <= 0
    return
  endif

  let view = winsaveview()
  try
    let diffoutput = s:getdiff(a:count, a:command, a:countercommand)
    let difflist = s:parsediff(diffoutput)
  catch
    execute "silent normal! " . a:count . a:command
    return
  finally
    call winrestview(view)
  endtry

  let originalcursor = s:hidecursor()
  try
    call highlightedundo#highlight#cancel()
    call s:blink(difflist, g:highlightedundo#highlight_duration_delete)
    execute "silent normal! " . a:count . a:command
    call s:glow(difflist, g:highlightedundo#highlight_duration_add)
  finally
    call s:restorecursor(originalcursor)
  endtry
endfunction "}}}
function! s:hidecursor() abort "{{{
  if s:GUI_RUNNING
    let cursor = &guicursor
    set guicursor+=n-o:block-NONE
  else
    let cursor = &t_ve
    set t_ve=
  endif
  return cursor
endfunction "}}}
function! s:restorecursor(originalcursor) abort "{{{
  if s:GUI_RUNNING
    set guicursor&
    let &guicursor = a:originalcursor
  else
    let &t_ve = a:originalcursor
  endif
endfunction "}}}

" for debug
function! highlightedundo#dumptree(filename) abort "{{{
  call writefile([string(undotree())], a:filename)
endfunction "}}}

" Region class "{{{
let s:region = {
  \   '__class__': 'Region',
  \   'head': [0, 0, 0, 0],
  \   'tail': [0, 0, 0, 0],
  \   'wise': 'v'
  \ }
function! s:Region(head, tail, wise) abort
  let region = deepcopy(s:region)
  let region.head = a:head
  let region.tail = a:tail
  let region.wise = a:wise
  return region
endfunction "}}}
" Subdiff class "{{{
let s:subdiff = {
  \   '__class__': 'Subdiff',
  \   'region': deepcopy(s:region),
  \   'lines': [],
  \ }
function! s:Subdiff(head, tail, type, lines) abort
  let subdiff = deepcopy(s:subdiff)
  let subdiff.region = s:Region(a:head, a:tail, a:type)
  let subdiff.lines = a:lines
  return subdiff
endfunction "}}}
" Diff class "{{{
let s:diff = {
  \   '__class__': 'Diff',
  \   'kind': '',
  \   'add': [],
  \   'delete': [],
  \ }
function! s:Diff(kind, from, to, lines) abort
  let diff = deepcopy(s:diff)
  let diff.kind = a:kind
  if a:kind ==# 'a'
    let addsubdiff = s:subdifflist_add(a:to[0], a:to[1], a:lines.add)
    call add(diff.add, addsubdiff)
  elseif a:kind ==# 'd'
    let delsubdiff = s:subdifflist_delete(a:from[0], a:from[1], a:lines.delete)
    call add(diff.delete, delsubdiff)
  elseif a:kind ==# 'c'
    let fromlinenrlist = range(a:from[0], a:from[1])
    let tolinenrlist = range(a:to[0], a:to[1])
    " XXX: To make it faster, restrict max 100 diff changes.
    for i in range(min([max([len(fromlinenrlist), len(tolinenrlist)]), 100]))
      if i < len(fromlinenrlist) && i < len(tolinenrlist)
        let before = a:lines.delete[i]
        let after = a:lines.add[i]
        let fromlinenr = fromlinenrlist[i]
        let tolinenr = tolinenrlist[i]
        let [delsubdiffs, addsubdiffs] = s:subdifflist_change(fromlinenr, tolinenr, before, after)
        call extend(diff.delete, delsubdiffs)
        call extend(diff.add, addsubdiffs)
      elseif i < len(fromlinenrlist)
        let before = a:lines.delete[i]
        let linenr = fromlinenrlist[i]
        let delsubdiff = s:subdifflist_delete(linenr, linenr, [before])
        call add(diff.delete, delsubdiff)
      elseif i < len(tolinenrlist)
        let after = a:lines.add[i]
        let linenr = tolinenrlist[i]
        let addsubdiff = s:subdifflist_add(linenr, linenr, [after])
        call add(diff.add, addsubdiff)
      endif
    endfor
  endif
  return diff
endfunction
function! s:subdifflist_delete(startline, endline, lines) abort "{{{
  let head = [0, a:startline, 1, 0]
  let tail = [0, a:endline, strlen(a:lines[-1]), 0]
  let subdiff = s:Subdiff(head, tail, 'V', a:lines)
  return subdiff
endfunction "}}}
function! s:subdifflist_add(startline, endline, lines) abort "{{{
  let head = [0, a:startline, 1, 0]
  let tail = [0, a:endline, strlen(a:lines[-1]), 0]
  let subdiff = s:Subdiff(head, tail, 'V', a:lines)
  return subdiff
endfunction "}}}
function! s:subdifflist_change(fromlinenr, tolinenr, before, after) abort "{{{
  let [changedbefore, changedafter] = s:getchanged(a:before, a:after)
  let [beforeindexes, afterindexes] = s:longestcommonsubsequence(
                                    \ changedbefore[0], changedafter[0])
  let delsubdiffs = s:splitchange(a:fromlinenr, changedbefore, beforeindexes)
  let addsubdiffs = s:splitchange(a:tolinenr, changedafter, afterindexes)
  return [delsubdiffs, addsubdiffs]
endfunction "}}}
"}}}
function! s:escape(string) abort  "{{{
  return escape(a:string, '~"\.^$[]*')
endfunction "}}}
" function! s:system(cmd) abort "{{{
if exists('*job_start')
  " NOTE: Arigatele...
  "       https://gist.github.com/mattn/566ba5fff15f947730f9c149e74f0eda
  function! s:system(cmd) abort
    let out = ''
    let job = job_start(a:cmd, {'out_cb': {ch,msg -> [execute('let out .= msg'), out]}, 'out_mode': 'raw'})
    while job_status(job) ==# 'run'
      sleep 1m
    endwhile
    return out
  endfunction
else
  function! s:system(cmd) abort
    return system(a:cmd)
  endfunction
endif
"}}}
function! s:undoablecount() abort "{{{
  let undotree = undotree()
  if undotree.entries == []
    return [0, 0]
  endif
  if undotree.seq_cur == 0
    let undocount = 0
    let redocount = len(undotree.entries)
    return [undocount, redocount]
  endif

  " get *correct* seq_cur
  let seq_cur = s:get_seq_of_curhead_parent(undotree)
  if seq_cur == 0
    return [0, 1]
  elseif seq_cur == -1
    let seq_cur = undotree.seq_cur
  endif

  let stack = []
  let parttree = {}
  let parttree.pos = [0]
  let parttree.tree = undotree.entries
  while 1
    let node = parttree.tree[parttree.pos[-1]]
    if node.seq == seq_cur
      break
    endif
    if has_key(node, 'alt')
      let alttree = {}
      let alttree.pos = parttree.pos + [0]
      let alttree.tree = node.alt
      call add(stack, alttree)
    endif
    let parttree.pos[-1] += 1
    if len(parttree.tree) <= parttree.pos[-1]
      if empty(stack)
        " shouldn't reach here
        let msg = [
          \   'highlightedundo: cannot find the current undo sequence!'
          \   'Could you :call highlightedundo#dumptree("~\undotree.txt") and'
          \   'report the dump file to <https://github.com/machakann/vim-highlightedundo/issues>'
          \   'if you do not mind? it does not include any buffer text.'
          \ ]
        echoerr join(msg)
      else
        let parttree = remove(stack, -1)
      endif
    endif
  endwhile
  let undocount = eval(join(parttree.pos, '+')) + 1
  let redocount = len(parttree.tree) - parttree.pos[-1] - 1
  return [undocount, redocount]
endfunction "}}}
function! s:get_seq_of_curhead_parent(undotree) abort "{{{
  if a:undotree.entries == []
    return -1
  endif
  let stack = []
  let parttree = {}
  let parttree.pos = [0]
  let parttree.tree = a:undotree.entries
  let node = {'seq': 0}
  while 1
    let parentnode = node
    let node = parttree.tree[parttree.pos[-1]]
    if has_key(node, 'curhead')
      return parentnode.seq
    endif
    if has_key(node, 'alt')
      let alttree = {}
      let alttree.pos = parttree.pos + [0]
      let alttree.tree = node.alt
      call add(stack, alttree)
    endif
    let parentnodepos = parttree.pos
    let parttree.pos[-1] += 1
    if len(parttree.tree) <= parttree.pos[-1]
      if empty(stack)
        break
      else
        let parttree = remove(stack, -1)
      endif
    endif
  endwhile
  return -1
endfunction "}}}
function! s:getchanged(before, after) abort "{{{
  if empty(a:before) || empty(a:after)
    let changedbefore = [a:before, 0, strlen(a:before)]
    let changedafter = [a:after, 0, strlen(a:after)]
    return [changedbefore, changedafter]
  endif

  let headpat = printf('\m\C^\%%[%s]', substitute(escape(a:before, '~"\.^$*'), '\([][]\)', '[\1]', 'g'))
  let start = matchend(a:after, headpat)
  if start == -1
    let start = 0
  endif

  let revbefore = join(reverse(split(a:before, '\zs')), '')
  let revafter = join(reverse(split(a:after, '\zs')), '')
  let tailpat = printf('\m\C^\%%[%s]', substitute(escape(revbefore, '~"\.^$*'), '\([][]\)', '[\1]', 'g'))
  let revend = matchend(revafter, tailpat)
  if revend == -1
    let revend = 0
  endif
  let end = strlen(a:after) - revend

  let commonhead = start == 0 ? '' : a:after[: start-1]
  let commontail = a:after[end :]
  let changedmask = printf('\m\C^%s\zs.*\ze%s$',
                         \ s:escape(commonhead), s:escape(commontail))
  let changedbefore = matchstrpos(a:before, changedmask)
  let changedafter = matchstrpos(a:after, changedmask)
  return [changedbefore, changedafter]
endfunction "}}}
function! s:splitchange(linenr, change, lcsindexes) abort "{{{
  " What I only can do for this func is just praying for my god so far...
  if empty(a:change[0])
    return []
  endif
  if empty(a:lcsindexes) || strchars(a:change[0]) == len(a:lcsindexes)
    let head = [0, a:linenr, a:change[1] + 1, 0]
    let tail = [0, a:linenr, a:change[2], 0]
    let subdiff = s:Subdiff(head, tail, 'v', [a:change[0]])
    return [subdiff]
  endif

  let charlist = split(a:change[0], '\zs')
  let indexes = range(len(charlist))
  call filter(indexes, '!count(a:lcsindexes, v:val)')

  let changes = []
  let columns = []
  for i in indexes
    let n = len(columns)
    if n == 0
      call add(columns, i)
    elseif n == 1
      if columns[-1] + 1 == i
        call add(columns, i)
      else
        call add(columns, columns[-1])
        call add(changes, columns)
        let columns = [i]
      endif
    else
      if columns[-1] + 1 == i
        let columns[-1] = i
      else
        call add(changes, columns)
        let columns = [i]
      endif
    endif
  endfor
  let n = len(columns)
  if n == 0
    " probably not possible
  elseif n == 1
    if columns[-1] + 1 == i
      call add(columns, i)
    else
      call add(columns, columns[-1])
    endif
  else
    if columns[-1] + 1 == i
      let columns[-1] = i
    endif
  endif
  call add(changes, columns)
  call map(changes, 's:charidx2idx(charlist, v:val)')
  call map(changes, 's:columns2subdiff(v:val, a:linenr, a:change)')
  return changes
endfunction "}}}
function! s:charidx2idx(charlist, columns) abort "{{{
  let indexes = [0, 0]
  if a:columns[0] != 0
    let indexes[0] = strlen(join(a:charlist[: a:columns[0] - 1], ''))
  endif
  if a:columns[1] != 0
    let indexes[1] = strlen(join(a:charlist[: a:columns[1]], '')) - 1
  endif
  return indexes
endfunction "}}}
function! s:columns2subdiff(columns, linenr, change) abort "{{{
  let text = a:change[0][a:columns[0] : a:columns[1]]
  let head = [0, a:linenr, a:change[1] + a:columns[0] + 1, 0]
  let tail = [0, a:linenr, a:change[1] + a:columns[1] + 1, 0]
  return s:Subdiff(head, tail, 'v', [text])
endfunction "}}}
function! s:calldiff(before, after) abort "{{{
  if s:TEMPBEFORE ==# ''
    let s:TEMPBEFORE = tempname()
    let s:TEMPAFTER = tempname()
  endif

  let ret1 = writefile(a:before, s:TEMPBEFORE)
  let ret2 = writefile(a:after, s:TEMPAFTER)
  if ret1 == -1 || ret2 == -1
    let s:TEMPBEFORE = ''
    let s:TEMPAFTER = ''
    echohl ErrorMsg
    echomsg 'highlightedundo: Failed to make tmp files.'
    echohl NONE
    return []
  endif

  let cmd = printf('diff -b "%s" "%s"', s:TEMPBEFORE, s:TEMPAFTER)
  let diff = split(s:system(cmd), '\r\?\n')
  return diff
endfunction "}}}
function! s:expandlinestr(linestr) abort "{{{
  let linenr = map(split(a:linestr, ','), 'str2nr(v:val)')
  if len(linenr) == 1
    let linenr = [linenr[0], linenr[0]]
  endif
  return linenr
endfunction "}}}
function! s:parsechunk(diffoutput, from, to, i, n) abort "{{{
  let i = a:i
  let lines = {}
  let lines.add = []
  let lines.delete = []
  while i < a:n
    let line = a:diffoutput[i]
    if !empty(matchstr(line, '\m\C^\d\+\%(,\d\+\)\?[acd]\d\+\%(,\d\+\)\?'))
      break
    endif

    " XXX: For performance, check only up to 250 chars.
    let [addedline, pos, _] = matchstrpos(line, '\m^>\s\zs.\{,250}')
    if pos != -1
      call add(lines.add, addedline)
      let i += 1
      continue
    endif

    let [deletedline, pos, _] = matchstrpos(line, '\m^<\s\zs.\{,250}')
    if pos != -1
      call add(lines.delete, deletedline)
      let i += 1
      continue
    endif

    let i += 1
  endwhile
  return [lines, i]
endfunction "}}}
function! s:parsediff(diffoutput) abort "{{{
  if a:diffoutput == []
    return []
  endif

  let parsed = []
  let n = len(a:diffoutput)
  let i = 0
  while i < n
    let line = a:diffoutput[i]
    let [whole, from, kind, to, _, _, _, _, _, _] = matchlist(line, '\m\C^\(\d\+\%(,\d\+\)\?\)\([acd]\)\(\d\+\%(,\d\+\)\?\)')
    let i += 1
    if empty(whole)
      continue
    endif

    let fromlinenr = s:expandlinestr(from)
    let tolinenr = s:expandlinestr(to)
    let [lines, i] = s:parsechunk(a:diffoutput, from, to, i, n)
    let diff = s:Diff(kind, fromlinenr, tolinenr, lines)
    call add(parsed, diff)
  endwhile
  return parsed
endfunction "}}}
function! s:getdiff(count, command, countercommand) abort "{{{
  let view = winsaveview()
  let countstr = a:count == 1 ? '' : string(a:count)

  let before = getline(1, '$')
  execute 'silent noautocmd normal! ' . countstr . a:command
  let after = getline(1, '$')
  let diffoutput = s:calldiff(before, after)
  if a:countercommand ==# ''
    return diffoutput
  endif

  execute 'silent noautocmd normal! ' . countstr . a:countercommand
  call winrestview(view)
  return diffoutput
endfunction "}}}
function! s:waitforinput(duration) abort "{{{
  let clock = highlightedundo#clock#new()
  let c = 0
  call clock.start()
  while empty(c) || c == 128
    let c = getchar(1)
    if clock.started && clock.elapsed() > a:duration
      break
    endif
  endwhile
  call clock.stop()
endfunction "}}}
function! s:blink(difflist, duration) abort "{{{
  if a:duration <= 0
    return
  endif
  if g:highlightedundo#highlight_mode < 2
    return
  endif

  let highlightlist = []
  for diff in a:difflist
    for subdiff in diff.delete
      if filter(copy(subdiff.lines), '!empty(v:val)') == []
        continue
      endif
      let h = highlightedundo#highlight#new(subdiff.region)
      call h.show('HighlightedundoDelete')
      call add(highlightlist, h)
    endfor
  endfor
  if empty(highlightlist)
    return
  endif

  redraw
  try
    call s:waitforinput(a:duration)
  finally
    for h in highlightlist
      call h.quench()
    endfor
  endtry
endfunction "}}}
function! s:glow(difflist, duration) abort "{{{
  if a:duration <= 0
    return
  endif
  if g:highlightedundo#highlight_mode < 1
    return
  endif

  let h = highlightedundo#highlight#new()
  let higroup = g:highlightedundo#highlight_mode == 1 ? 'HighlightedundoChange' : 'HighlightedundoAdd'
  for diff in a:difflist
    for subdiff in diff.add
      if filter(copy(subdiff.lines), '!empty(v:val)') == []
        continue
      endif
      call h.add(subdiff.region)
    endfor
  endfor
  call h.show(higroup)
  call h.quench_timer(a:duration)
endfunction "}}}

" solving Longest Common Subsequence problem
function! s:lcsmap(n) abort "{{{
  let d = []
  for i in range(a:n)
    let d += [repeat([0], a:n)]
  endfor
  return d
endfunction
let s:dmax = 81
let s:lcsmap = s:lcsmap(s:dmax)
"}}}
function! s:longestcommonsubsequence(a, b) abort "{{{
  let a = split(a:a, '\zs')
  let b = split(a:b, '\zs')
  let na = len(a)
  let nb = len(b)
  if na == 0 || nb == 0
    return [[], []]
  endif
  if na == 1
    return s:lcs_for_a_char(a:a, a:b)
  endif
  if nb == 1
    return s:lcs_for_a_char(a:b, a:a)
  endif

  let nmax = max([na, nb])
  if nmax >= s:dmax
    let s:dmax = nmax + 1
    let s:lcsmap = s:lcsmap(s:dmax)
  endif
  let d = copy(s:lcsmap)
  for i in range(1, na)
    for j in range(1, nb)
      if a[i - 1] ==# b[j - 1]
        let d[i][j] = d[i - 1][j - 1] + 1
      else
        let d[i][j] = max([d[i - 1][j], d[i][j - 1]])
      endif
    endfor
  endfor
  return s:backtrack(d, a, b, na, nb)
endfunction "}}}
function! s:lcs_for_a_char(a, b) abort "{{{
  let commonindex = stridx(a:b, a:a)
  if commonindex == -1
    let aindexes = []
    let bindexes = []
  else
    let aindexes = [0]
    let bindexes = [commonindex]
  endif
  return [aindexes, bindexes]
endfunction "}}}
function! s:backtrack(d, a, b, na, nb) abort "{{{
  let aindexes = []
  let bindexes = []
  let i = a:na
  let j = a:nb
  while i != 0 && j != 0
    if a:a[i - 1] ==# a:b[j - 1]
      let i -= 1
      let j -= 1
      call add(aindexes, i)
      call add(bindexes, j)
    elseif a:d[i - 1][j] >= a:d[i][j - 1]
      let i -= 1
    else
      let j -= 1
    endif
  endwhile
  return [reverse(aindexes), reverse(bindexes)]
endfunction "}}}

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
