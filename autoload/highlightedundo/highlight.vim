" highlight object - managing highlight on a buffer

let s:save_cpo = &cpoptions
set cpoptions&vim

" variables "{{{
" null valiables
let s:null_pos = [0, 0, 0, 0]

" constants
let s:on = 1
let s:off = 0
let s:maxcol = 2147483647

" types
let s:type_list = type([])

" patchs
if v:version > 704 || (v:version == 704 && has('patch237'))
  let s:has_patch_7_4_362 = has('patch-7.4.362')
  let s:has_patch_7_4_392 = has('patch-7.4.392')
else
  let s:has_patch_7_4_362 = v:version == 704 && has('patch362')
  let s:has_patch_7_4_392 = v:version == 704 && has('patch392')
endif

" features
let s:has_gui_running = has('gui_running')

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID
"}}}

function! highlightedundo#highlight#new() abort  "{{{
  return deepcopy(s:highlight)
endfunction "}}}

let s:quench_table = {}
" s:highlight "{{{
let s:highlight = {
      \   'status': s:off,
      \   'id': [],
      \   'order_list': [],
      \   'bufnr': 0,
      \   'winid': 0,
      \   'timer_id': 0,
      \ }
"}}}
function! s:highlight.add(hi_group, order) abort "{{{
  call add(self.order_list, [a:hi_group, a:order])
endfunction "}}}
function! s:highlight.show() dict abort "{{{
  if empty(self.order_list)
    return 0
  endif
  if self.status is s:on
    call self.quench()
  endif

  for [hi_group, order] in self.order_list
    let self.id += [matchaddpos(hi_group, [order])]
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:on
  let self.bufnr = bufnr('%')
  let self.winid = win_getid()
  return 1
endfunction "}}}
function! s:highlight.quench(...) dict abort "{{{
  let options = s:shift_options()
  try
    call self._quench()
  catch /^Vim\%((\a\+)\)\=:E523/
    " NOTE: In case of "textlock"ed!
    call self.quench_timer(50)
  finally
    call s:restore_options(options)
  endtry
  call timer_stop(self.timer_id)
  call s:clear_autocmds()
endfunction "}}}
function! s:highlight._quench() abort "{{{
  if self.status is s:off
    return
  endif

  let winid = win_getid()
  let view = winsaveview()
  if winid == self.winid
    call s:matchdelete_all(self.id)
    let succeeded = 1
  else
    if s:is_in_cmdline_window()
      augroup highlightedundo-pause-quenching
        autocmd!
        execute printf("autocmd CmdWinLeave * call s:after_CmdWinLeave(%d)", self.timer_id)
      augroup END
      let succeeded = 0
    else
      noautocmd let reached = win_gotoid(self.winid)
      if reached
        call s:matchdelete_all(self.id)
      else
        call filter(self.id, 0)
      endif
      let succeeded = 1
      noautocmd call win_gotoid(winid)
      call winrestview(view)
    endif
  endif

  if succeeded
    let self.status = s:off
  endif
  return
endfunction "}}}
function! s:highlight.quench_timer(time) dict abort "{{{
  let id = timer_start(a:time, self.quench)
  let s:quench_table[id] = self
  let self.timer_id = id
  call s:set_autocmds(id)
  return id
endfunction "}}}
function! s:after_CmdWinLeave(id) abort "{{{
  augroup highlightedundo-pause-quenching
    autocmd!
  augroup END
  let highlight = s:quench_table[a:id]
  call remove(s:quench_table, a:id)
  call highlight.quench_timer(0)
endfunction "}}}
function! s:set_autocmds(id) abort "{{{
  augroup highlightedundo-highlight
    autocmd!
    " execute printf('autocmd TextChanged <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd InsertEnter <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd BufUnload <buffer> call s:cancel_highlight(%s)', a:id)
    execute printf('autocmd BufEnter * call s:switch_highlight(%s)', a:id)
  augroup END
endfunction "}}}
function! s:clear_autocmds() abort "{{{
  augroup highlightedundo-highlight
    autocmd!
  augroup END
endfunction "}}}
function! s:cancel_highlight(id) abort  "{{{
  let highlight = s:quench_table[a:id]
  if highlight != {}
    call highlight.quench()
  endif
endfunction "}}}
function! s:switch_highlight(id) abort "{{{
  let highlight = s:quench_table[a:id]
  if highlight != {} && highlight.winid == win_getid()
    if highlight.bufnr == bufnr('%')
      call highlight.show()
    else
      call highlight.quench()
    endif
  endif
endfunction "}}}


function! s:matchdelete_all(ids) abort "{{{
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
endfunction "}}}
" function! s:is_in_cmdline_window() abort  "{{{
if s:has_patch_7_4_392
  function! s:is_in_cmdline_window() abort
    return getcmdwintype() !=# ''
  endfunction
else
  function! s:is_in_cmdline_window() abort
    let is_in_cmdline_window = 0
    try
      execute 'tabnext ' . tabpagenr()
    catch /^Vim\%((\a\+)\)\=:E11/
      let is_in_cmdline_window = 1
    catch
    finally
      return is_in_cmdline_window
    endtry
  endfunction
endif
"}}}
function! s:shift_options() abort "{{{
  let options = {}

  """ tweak appearance
  " hide_cursor
  if s:has_gui_running
    let options.cursor = &guicursor
    set guicursor+=a:block-NONE
  else
    let options.cursor = &t_ve
    set t_ve=
  endif

  return options
endfunction "}}}
function! s:restore_options(options) abort "{{{
  if s:has_gui_running
    set guicursor&
    let &guicursor = a:options.cursor
  else
    let &t_ve = a:options.cursor
  endif
endfunction "}}}


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
