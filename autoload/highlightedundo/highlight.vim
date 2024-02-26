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
      \   'group': '',
      \   'id': [],
      \   'order_list': [],
      \   'region': {},
      \   'bufnr': 0,
      \   'winid': 0,
      \   'timer_id': 0,
      \ }
"}}}
function! s:highlight.add(region) abort "{{{
  let self.region = deepcopy(a:region)
  if a:region.wise ==# 'char' || a:region.wise ==# 'v'
    let self.order_list += s:highlight_order_charwise(a:region)
  elseif a:region.wise ==# 'line' || a:region.wise ==# 'V'
    let self.order_list += s:highlight_order_linewise(a:region)
  endif
endfunction "}}}
function! s:highlight.show(...) dict abort "{{{
  if empty(self.order_list)
    return 0
  endif

  if a:0 < 1
    if empty(self.group)
      return 0
    else
      let hi_group = self.group
    endif
  else
    let hi_group = a:1
  endif

  if self.status is s:on
    if hi_group ==# self.group
      return 0
    else
      call self.quench()
    endif
  endif

  for order in self.order_list
    let self.id += s:matchaddpos(hi_group, order)
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:on
  let self.group = hi_group
  let self.bufnr = bufnr('%')
  let self.winid = s:win_getid()
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
  redraw
endfunction "}}}
function! s:highlight._quench() abort "{{{
  if self.status is s:off
    return
  endif

  let winid = s:win_getid()
  let view = winsaveview()
  if s:win_getid() == self.winid
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
      let reached = s:win_gotoid(self.winid)
      if reached
        call s:matchdelete_all(self.id)
      else
        call filter(self.id, 0)
      endif
      let succeeded = 1
      call s:win_gotoid(winid)
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
  if highlight != {} && highlight.winid == s:win_getid()
    if highlight.bufnr == bufnr('%')
      call highlight.show()
    else
      call highlight.quench()
    endif
  endif
endfunction "}}}


" private functions
function! s:highlight_order_charwise(region) abort  "{{{
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && s:is_equal_or_ahead(a:region.tail, a:region.head)
    if a:region.head[1] == a:region.tail[1]
      let order += [a:region.head[1:2] + [a:region.tail[2] - a:region.head[2] + 1]]
      let n += 1
    else
      for lnum in range(a:region.head[1], a:region.tail[1])
        if lnum == a:region.head[1]
          let order += [a:region.head[1:2] + [col([a:region.head[1], '$']) - a:region.head[2] + 1]]
        elseif lnum == a:region.tail[1]
          let order += [[a:region.tail[1], 1] + [a:region.tail[2]]]
        else
          let order += [[lnum]]
        endif

        if n == 7
          let order_list += [order]
          let order = []
          let n = 0
        else
          let n += 1
        endif
      endfor
    endif
  endif
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}
function! s:highlight_order_linewise(region) abort  "{{{
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && a:region.head[1] <= a:region.tail[1]
    for lnum in range(a:region.head[1], a:region.tail[1])
      let order += [[lnum]]
      if n == 7
        let order_list += [order]
        let order = []
        let n = 0
      else
        let n += 1
      endif
    endfor
  endif
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}
" function! s:matchaddpos(group, pos) abort "{{{
if s:has_patch_7_4_362
  function! s:matchaddpos(group, pos) abort
    return [matchaddpos(a:group, a:pos)]
  endfunction
else
  function! s:matchaddpos(group, pos) abort
    let id_list = []
    for pos in a:pos
      if len(pos) == 1
        let id_list += [matchadd(a:group, printf('\%%%dl', pos[0]))]
      else
        let id_list += [matchadd(a:group, printf('\%%%dl\%%>%dc.*\%%<%dc', pos[0], pos[1]-1, pos[1]+pos[2]))]
      endif
    endfor
    return id_list
  endfunction
endif
"}}}
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
function! s:is_equal_or_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] >= a:pos2[2])
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

" for compatibility
" function! s:win_getid(...) abort{{{
if exists('*win_getid')
  let s:win_getid = function('win_getid')
else
  function! s:win_getid(...) abort
    let winnr = get(a:000, 0, winnr())
    let tabnr = get(a:000, 1, tabpagenr())
  endfunction
endif
"}}}
" function! s:win_gotoid(id) abort{{{
if exists('*win_gotoid')
  function! s:win_gotoid(id) abort
    noautocmd let ret = win_gotoid(a:id)
    return ret
  endfunction
else
  function! s:win_gotoid(id) abort
    let [winnr, tabnr] = a:id

    if tabnr != tabpagenr()
      execute 'noautocmd tabnext ' . tabnr
      if tabpagenr() != tabnr
        return 0
      endif
    endif

    try
      if winnr != winnr()
        execute printf('noautocmd %swincmd w', winnr)
      endif
    catch /^Vim\%((\a\+)\)\=:E16/
      return 0
    endtry
    return 1
  endfunction
endif
"}}}

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
