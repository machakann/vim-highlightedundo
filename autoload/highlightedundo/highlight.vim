" highlight object - managing highlight on a buffer

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:ON = 1
let s:OFF = 0
let s:GUI_RUNNING = has('gui_running')

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID


let s:highlight = {
      \   'status': s:OFF,
      \   'id': [],
      \   'order_list': [],
      \   'bufnr': 0,
      \   'winid': 0,
      \   'timer_id': 0,
      \ }
function! highlightedundo#highlight#new() abort
  return deepcopy(s:highlight)
endfunction


function! s:highlight.add(hi_group, order) abort
  call add(self.order_list, [a:hi_group, a:order])
endfunction


function! s:highlight.show() dict abort
  if empty(self.order_list)
    return 0
  endif
  if self.status is s:ON
    call self.quench()
  endif

  for [hi_group, order] in self.order_list
    let self.id += [matchaddpos(hi_group, [order])]
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:ON
  let self.bufnr = bufnr('%')
  let self.winid = win_getid()
  return 1
endfunction


function! s:highlight.quench(...) dict abort
  try
    call self._quench()
  catch /^Vim\%((\a\+)\)\=:E523/
    " NOTE: In case of "textlock"ed!
    call self.quench_timer(1)
  endtry
  call timer_stop(self.timer_id)
  call s:clear_autocmds()
endfunction


function! s:highlight._quench() abort
  if self.status is s:OFF
    return
  endif

  let winid = win_getid()
  let view = winsaveview()
  if winid == self.winid
    call s:matchdelete_all(self.id)
    let succeeded = 1
    " This :redraw suppresses flickering when highlights are deleted
    redraw
  else
    if getcmdwintype() !=# '' || s:is_in_popup_terminal_window()
      " NOTE: cannot move out from commandline-window
      " NOTE: cannot move out from popup terminal window
      augroup highlightedundo-pause-quenching
        autocmd!
        execute printf("autocmd WinEnter * call s:after_WinEnter(%d)", self.timer_id)
      augroup END
      let succeeded = 0
    else
      noautocmd let reached = win_gotoid(self.winid)
      if reached
        call s:matchdelete_all(self.id)
        " This :redraw suppresses flickering when highlights are deleted
        redraw
      else
        call filter(self.id, 0)
      endif
      let succeeded = 1
      noautocmd call win_gotoid(winid)
      call winrestview(view)
    endif
  endif

  if succeeded
    let self.status = s:OFF
  endif
  return
endfunction


let s:quench_table = {}
function! s:highlight.quench_timer(time) dict abort
  let id = timer_start(a:time, self.quench)
  let s:quench_table[id] = self
  let self.timer_id = id
  call s:set_autocmds(id)
  return id
endfunction


function! s:after_WinEnter(id) abort
  augroup highlightedundo-pause-quenching
    autocmd!
  augroup END
  let highlight = s:quench_table[a:id]
  call remove(s:quench_table, a:id)
  call highlight.quench_timer(0)
endfunction


function! s:set_autocmds(id) abort
  augroup highlightedundo-highlight
    autocmd!
    " execute printf('autocmd TextChanged <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd InsertEnter <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd BufUnload <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd BufLeave <buffer> call s:cancel_highlight(%s)', a:id)
  augroup END
endfunction


function! s:clear_autocmds() abort
  augroup highlightedundo-highlight
    autocmd!
  augroup END
endfunction


function! s:cancel_highlight(id) abort
  let highlight = s:quench_table[a:id]
  if highlight != {}
    call highlight.quench()
  endif
endfunction


function! s:matchdelete_all(ids) abort
  if empty(a:ids)
    return
  endif

  let alive_ids = map(getmatches(), 'v:val.id')
  " Return if another plugin called clearmatches() which clears *ALL*
  " highlights including others set.
  if empty(alive_ids)
    return
  endif
  if !count(alive_ids, a:ids[0])
    return
  endif

  for id in a:ids
    try
      call matchdelete(id)
    catch
    endtry
  endfor
  call filter(a:ids, 0)
endfunction


if exists('*popup_list')
  function! s:is_in_popup_terminal_window() abort
    return &buftype is# 'terminal' && count(popup_list(), win_getid())
  endfunction
else
  function! s:is_in_popup_terminal_window() abort
    return 0
  endfunction
endif


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set ts=2 sts=2 sw=2:
