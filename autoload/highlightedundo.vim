let s:save_cpo = &cpoptions
set cpoptions&vim

let g:highlightedundo#highlight_mode = get(g:, 'highlightedundo#highlight_mode', 1)
let g:highlightedundo#highlight_duration_delete = get(g:, 'highlightedundo#highlight_duration_delete', 200)
let g:highlightedundo#highlight_duration_add = get(g:, 'highlightedundo#highlight_duration_add', 500)
let g:highlightedundo#highlight_extra_lines = get(g:, 'highlighbarundo#highlight_extra_lines', &lines)
let g:highlightedundo#debounce = get(g:, 'highlightedundo#debounce', 60)

let s:FALSE = 0
let s:TRUE = 1
let s:TEMPBEFORE = ''
let s:TEMPAFTER = ''
let s:GUI_RUNNING = has('gui_running')


function! highlightedundo#undo() abort
  let [n, _] = s:undoablecount()
  let safecount = min([v:count1, n])
  call s:debounce(safecount, 'u', "\<C-r>")
endfunction


function! highlightedundo#redo() abort
  let [_, n] = s:undoablecount()
  let safecount = min([v:count1, n])
  call s:debounce(safecount, "\<C-r>", 'u')
endfunction


function! highlightedundo#Undo() abort
  call s:debounce(1, 'U', 'U')
endfunction


function! highlightedundo#gminus() abort
  let undotree = undotree()
  let safecount = min([v:count1, undotree.seq_cur + 1])
  call s:debounce(safecount, 'g-', 'g+')
endfunction


function! highlightedundo#gplus() abort
  let undotree = undotree()
  let safecount = min([v:count1, undotree.seq_last - undotree.seq_cur])
  call s:debounce(safecount, 'g+', 'g-')
endfunction


let s:command = ''
let s:timer = -1
function! s:debounce(count, command, countercommand) abort
  if s:timer != -1
    execute "normal! " . s:command
    call timer_stop(s:timer)
  endif
  let s:command = a:command
  let s:timer = timer_start(g:highlightedundo#debounce,
  \ {-> s:common(a:count, a:command, a:countercommand)})
endfunction


function! s:common(count, command, countercommand) abort
  let s:timer = -1
  if a:count <= 0
    return
  endif

  let view = winsaveview()
  let countstr = a:count == 1 ? '' : string(a:count)
  let before = getline(1, '$')
  execute 'silent noautocmd normal! ' . countstr . a:command
  let cursor_to_be_highlighted = getpos('.')
  let after = getline(1, '$')
  let range_after = s:highlight_range(g:highlightedundo#highlight_extra_lines)
  try
    let hunks = s:diff(before, after)
  finally
    if a:countercommand !=# ''
      execute 'silent noautocmd normal! ' . countstr . a:countercommand
    endif
    call setpos('.', cursor_to_be_highlighted)
    let range_before = s:highlight_range(g:highlightedundo#highlight_extra_lines)
    call winrestview(view)
  endtry
  try
    let difflist = s:parsediff(hunks, before, after, range_before, range_after)
  catch
    let difflist = []
  endtry

  let originalcursor = s:hidecursor()
  try
    call s:quench_highlight()
    call setpos('.', cursor_to_be_highlighted)
    call s:blink(difflist, g:highlightedundo#highlight_duration_delete)
    execute "silent normal! " . a:count . a:command
    call s:glow(difflist, g:highlightedundo#highlight_duration_add)
  finally
    call s:restorecursor(originalcursor)
  endtry
endfunction


function! s:highlight_range(extra_lines) abort
  let highlight_start_idx = max([1, line('w0') - a:extra_lines]) - 1
  let highlight_end_idx = min([line('$'), line('w$') + a:extra_lines]) - 1
  return [highlight_start_idx, highlight_end_idx]
endfunction


function! s:hidecursor() abort
  if s:GUI_RUNNING
    let cursor = &guicursor
    set guicursor+=n-o:block-NONE
  else
    let cursor = &t_ve
    set t_ve=
  endif
  return cursor
endfunction


function! s:restorecursor(originalcursor) abort
  if s:GUI_RUNNING
    set guicursor&
    let &guicursor = a:originalcursor
  else
    let &t_ve = a:originalcursor
  endif
endfunction


let s:Diff = {
\   'kind': '',
\   'delete': [],
\   'add': [],
\ }
function! s:Diff(kind, list1, ...) abort
  let diff = copy(s:Diff)
  let diff.kind = a:kind
  if a:kind is# 'a'
    let diff.add = copy(a:list1)
  elseif a:kind is# 'd'
    let diff.delete = copy(a:list1)
  else
    let diff.delete = copy(a:list1)
    let diff.add = copy(a:1)
  endif
  return diff
endfunction


function! s:undoablecount() abort
  let undotree = undotree()
  if undotree.entries == []
    return [0, 0]
  endif
  if undotree.seq_cur == 0
    let undocount = 0
    let redocount = len(undotree.entries)
    return [undocount, redocount]
  endif

  let seq_cur = undotree.seq_cur
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
          \   'highlightedundo: cannot find the current undo sequence!',
          \   'Could you :call highlightedundo#dumptree("~\undotree.txt") and',
          \   'report the dump file to <https://github.com/machakann/vim-highlightedundo/issues>',
          \   'if you do not mind? it does not include any buffer text.',
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
endfunction


if exists('*diff')
  function! s:diff(before, after) abort
    return diff(a:before, a:after, {'output': 'indices'})
  endfunction
elseif has('nvim-0.6.0')
  function! s:diff(before, after) abort
    let result = v:lua.vim.diff(join(a:before, "\n"), join(a:after, "\n"), {'result_type': 'indices'})
    return map(result, { -> {'from_idx': v:val[0] - 1, 'from_count': v:val[1], 'to_idx': v:val[2] - 1, 'to_count': v:val[3]} })
  endfunction
else
  function! s:diff(before, after) abort
    let diffoutput = s:calldiff(a:before, a:after)
    let result = copy(diffoutput)
    let result = filter(result, {-> v:val =~# '\m^\(\d\+\%(,\d\+\)\?\)\([acd]\)\(\d\+\%(,\d\+\)\?\)'})
    return map(result, {-> s:diffheader2dict(v:val)})
  endfunction
endif


function! s:calldiff(before, after) abort
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
endfunction


if has('nvim')
  function! s:system(cmd) abort
    let out = []
    let job = jobstart(a:cmd, {'on_stdout': {_,data -> extend(out, data)}})
    call jobwait([job])
    return join(out, "\n")
  endfunction
else
  " NOTE: https://gist.github.com/mattn/566ba5fff15f947730f9c149e74f0eda
  function! s:system(cmd) abort
    let out = ''
    let job = job_start(a:cmd, {'out_cb': {ch,msg -> [execute('let out .= msg'), out]}, 'out_mode': 'raw'})
    while job_status(job) ==# 'run'
      sleep 1m
    endwhile
    return out
  endfunction
endif


function! s:diffheader2dict(header) abort
  " Convert '1a2'     -> #{from_idx: 0, from_count: 0, to_idx: 1, to_count, 1}
  " Convert '1a2,4'   -> #{from_idx: 0, from_count: 0, to_idx: 1, to_count, 3}
  " Convert '2d1'     -> #{from_idx: 1, from_count: 1, to_idx: 1, to_count, 0}
  " Convert '2,4d1'   -> #{from_idx: 1, from_count: 3, to_idx: 1, to_count, 0}
  " Convert '1c1'     -> #{from_idx: 0, from_count: 1, to_idx: 0, to_count, 1}
  " Convert '1,3c1,2' -> #{from_idx: 0, from_count: 3, to_idx: 0, to_count, 2}
  let d = {}
  let [from, kind, to] = matchlist(a:header, '\m\C^\(\d\+\%(,\d\+\)\?\)\([acd]\)\(\d\+\%(,\d\+\)\?\)')[1:3]
  let [d.from_idx, d.from_count] = s:parse_line_range(kind, from)
  let [d.to_idx, d.to_count] = s:parse_line_range(kind, to)
  if kind is# 'd'
    let d.to_idx += 1
  elseif kind is# 'a'
    let d.from_idx += 1
  endif
  if kind is# 'a'
    let d.from_count = 0
  elseif kind is# 'd'
    let d.to_count = 0
  endif
  return d
endfunction


function! s:parse_line_range(kind, str) abort
  let [start, end] = matchlist(a:str, '\m\(\d\+\)\%(,\(\d\+\)\)\?')[1:2]
  let idx = str2nr(start) - 1
  if end is# ''
    let l:count = 1
  else
    let l:count = str2nr(end) - str2nr(start) + 1
  endif
  return [idx, l:count]
endfunction


function! s:parsediff(hunks, before, after, ...) abort
  let range_before = get(a:000, 0, [0, len(a:before) - 1])
  let range_after = get(a:000, 1, [0, len(a:after) - 1])

  let diffs = []
  for hunk in a:hunks
    if hunk.from_count != 0 && hunk.to_count == 0
      let startlnum = max([hunk.from_idx, range_before[0]]) + 1
      let endlnum = min([hunk.from_idx + hunk.from_count, range_before[1] + 1])
      if startlnum <= endlnum
        let d = map(range(startlnum, endlnum), 's:Diff(''d'', [v:val])')
        call extend(diffs, d)
      endif
    elseif hunk.from_count == 0 && hunk.to_count != 0
      let startlnum = max([hunk.to_idx, range_after[0]]) + 1
      let endlnum = min([hunk.to_idx + hunk.to_count, range_after[1] + 1])
      if startlnum <= endlnum
        let d = map(range(startlnum, endlnum), 's:Diff(''a'', [v:val])')
        call extend(diffs, d)
      endif
    elseif hunk.from_count != 0 && hunk.to_count != 0
      if hunk.from_count == hunk.to_count
        " Numbers of lines to delete and add are same
        " There may be one-by-one correspondence
        call s:add_changes(diffs, a:before, a:after, hunk.from_idx, hunk.to_idx, hunk.from_count, range_before, range_after)
      else
        " Numbers of lines to delete and add are different
        let corr = s:search_correspondence(a:before, a:after, hunk)
        let n_del_1 = max([(corr[0] - hunk.from_idx) - (corr[1] - hunk.to_idx), 0])
        let n_add_1 = max([(corr[1] - hunk.to_idx) - (corr[0] - hunk.from_idx), 0])
        let n_change = min([hunk.from_idx + hunk.from_count - corr[0], hunk.to_idx + hunk.to_count - corr[1]])
        let n_del_2 = max([hunk.from_count - n_del_1 - n_change, 0])
        let n_add_2 = max([hunk.to_count - n_add_1 - n_change, 0])

        let startlnum = max([hunk.from_idx, range_before[0]]) + 1
        let endlnum = min([hunk.from_idx + n_del_1, range_before[1] + 1])
        if startlnum <= endlnum
          let d = map(range(startlnum, endlnum), 's:Diff(''d'', [v:val])')
          call extend(diffs, d)
        endif

        let startlnum = max([hunk.to_idx, range_after[0]]) + 1
        let endlnum = min([hunk.to_idx + n_add_1, range_after[1] + 1])
        if startlnum <= endlnum
          let d = map(range(startlnum, endlnum), 's:Diff(''a'', [v:val])')
          call extend(diffs, d)
        endif

        call s:add_changes(diffs, a:before, a:after, corr[0], corr[1], n_change, range_before, range_after)

        let startlnum = max([hunk.from_idx + n_del_1 + n_change, range_before[0]]) + 1
        let endlnum = min([hunk.from_idx + n_del_1 + n_change + n_del_2, range_before[1] + 1])
        if startlnum <= endlnum
          let d = map(range(startlnum, endlnum), 's:Diff(''d'', [v:val])')
          call extend(diffs, d)
        endif

        let startlnum = max([hunk.to_idx + n_add_1 + n_change, range_after[0]]) + 1
        let endlnum = min([hunk.to_idx + n_add_1 + n_change + n_add_2, range_after[1] + 1])
        if startlnum <= endlnum
          let d = map(range(startlnum, endlnum), 's:Diff(''a'', [v:val])')
          call extend(diffs, d)
        endif
      endif
    endif
  endfor
  return diffs
endfunction


function! s:add_changes(diffs, before, after, from_idx, to_idx, n, range_before, range_after) abort
  let start = max([0, min([a:range_before[0] - a:from_idx, a:range_after[0] - a:to_idx])])
  let end = min([a:n - 1, max([a:range_before[1] - a:from_idx, a:range_after[1] - a:to_idx])])
  if start > end
    return
  endif

  for i in range(start, end)
    let idx_before = a:from_idx + i
    let idx_after = a:to_idx + i
    if (idx_before < a:range_before[0] || a:range_before[1] < idx_before)
    \ && (idx_after < a:range_after[0] || a:range_after[1] < idx_after)
      continue
    endif
    let lnum_before = idx_before + 1
    let lnum_after = idx_after + 1
    let line_before = a:before[idx_before]
    let line_after = a:after[idx_after]
    let changelist = highlightedundo#chardiff#diff(line_before, line_after)
    for change in changelist
      let [del_col, del_count] = change[0]
      let [add_col, add_count] = change[1]
      if del_count != 0 && add_count != 0
        let d = s:Diff('c', [lnum_before, del_col, del_count], [lnum_after, add_col, add_count])
        call add(a:diffs, d)
      elseif del_count != 0
        if a:range_before[0] <= idx_before && idx_before <= a:range_before[1]
          let d = s:Diff('d', [lnum_before, del_col, del_count])
          call add(a:diffs, d)
        endif
      elseif add_count != 0
        if a:range_after[0] <= idx_after && idx_after <= a:range_after[1]
          let d = s:Diff('a', [lnum_after, add_col, add_count])
          call add(a:diffs, d)
        endif
      endif
    endfor
  endfor
endfunction


function! s:search_correspondence(before, after, hunk) abort
  let acceptable_shift = 5
  if len(a:before) <= len(a:after)
    let needle = a:before[a:hunk.from_idx]
    let stuck = a:after
    let n = min([a:hunk.to_count, acceptable_shift]) - 1
    let candidates = uniq(sort(range(a:hunk.to_idx, a:hunk.to_idx + n) +
                   \ [a:hunk.to_idx + a:hunk.to_count - a:hunk.from_count]))
  else
    let needle = a:after[a:hunk.to_idx]
    let stuck = a:before
    let n = min([a:hunk.from_count, acceptable_shift]) - 1
    let candidates = uniq(sort(range(a:hunk.from_idx, a:hunk.from_idx + n) +
                  \ [a:hunk.from_idx + a:hunk.from_count - a:hunk.to_count]))
  endif
  let maxlnum = len(stuck)
  call filter(candidates, '0 <= v:val && v:val < maxlnum')
  let p = -1
  let corr_idx = -1
  for idx in candidates
    let pp = highlightedundo#chardiff#similarity(needle, stuck[idx])
    if pp > p
      let p = pp
      let corr_idx = idx
    endif
  endfor
  if len(a:before) <= len(a:after)
    let corr_idx = corr_idx > 0.5 ? corr_idx : a:hunk.to_idx
    let correspondence = [a:hunk.from_idx, corr_idx]
  else
    let corr_idx = corr_idx > 0.5 ? corr_idx : a:hunk.from_idx
    let correspondence = [corr_idx, a:hunk.to_idx]
  endif
  return correspondence
endfunction


let s:highlights = []
function! s:quench_highlight() abort
  for h in s:highlights
    call h.quench()
  endfor
  call filter(s:highlights, 0)
endfunction


function! s:blink(difflist, duration) abort
  if a:duration <= 0
    return
  endif
  if g:highlightedundo#highlight_mode < 2
    return
  endif

  let isempty = s:TRUE
  let h = highlightedundo#highlight#new()
  for diff in a:difflist
    let isempty = s:FALSE
    call h.add('HighlightedundoDelete', diff.delete)
  endfor
  if isempty
    return
  endif

  call h.show()
  redraw
  try
    call s:waitforinput(a:duration)
  finally
    call h.quench()
  endtry
endfunction


function! s:waitforinput(duration) abort
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
endfunction


function! s:glow(difflist, duration) abort
  if a:duration <= 0
    return
  endif
  if g:highlightedundo#highlight_mode < 1
    return
  endif

  let h = highlightedundo#highlight#new()
  let hi_change = g:highlightedundo#highlight_mode < 2 ?
                \ 'HighlightedundoChange' : 'HighlightedundoAdd'
  for diff in a:difflist
    if diff.kind is# 'a'
      call h.add('HighlightedundoAdd', diff.add)
    elseif diff.kind is# 'c'
      call h.add(hi_change, diff.add)
    endif
  endfor
  call h.show()
  call h.quench_timer(a:duration)
  call add(s:highlights, h)
endfunction


" for debug
function! highlightedundo#dumptree(filename) abort
  call writefile([string(undotree())], a:filename)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2:
