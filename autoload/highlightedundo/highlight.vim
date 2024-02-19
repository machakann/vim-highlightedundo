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

function! highlightedundo#highlight#new(region) abort  "{{{
  let highlight = deepcopy(s:highlight)
  let highlight.region = deepcopy(a:region)
  if a:region.wise ==# 'char' || a:region.wise ==# 'v'
    let highlight.order_list = s:highlight_order_charwise(a:region)
  elseif a:region.wise ==# 'line' || a:region.wise ==# 'V'
    let highlight.order_list = s:highlight_order_linewise(a:region)
  elseif a:region.wise ==# 'block' || a:region.wise[0] ==# "\<C-v>"
    let highlight.order_list = s:highlight_order_blockwise(a:region)
  endif
  return highlight
endfunction "}}}

" s:highlight "{{{
let s:highlight = {
      \   'status': s:off,
      \   'group': '',
      \   'id': [],
      \   'order_list': [],
      \   'region': {},
      \   'bufnr': 0,
      \   'winid': 0,
      \ }
"}}}
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
function! s:highlight.quench() dict abort "{{{
  if self.status is s:off
    return 0
  endif

  let winid = s:win_getid()
  let view = winsaveview()
  if s:win_getid() == self.winid
    call s:matchdelete_all(self.id)
    let succeeded = 1
  else
    if s:is_in_cmdline_window()
      let s:paused += [self]
      augroup highlightedundo-pause-quenching
        autocmd!
        autocmd CmdWinLeave * call s:got_out_of_cmdwindow()
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
  return succeeded
endfunction "}}}
function! s:highlight.quench_timer(time) dict abort "{{{
  if g:highlightedundo#fast_mode && get(s:, 'timer_id', -1) >= 0
      return s:timer_id
  endif

  let id = timer_start(a:time, s:SID . 'quench')
  if g:highlightedundo#fast_mode
    let s:timer_id = id
  endif
  let s:quench_table[id] = self
  call s:set_autocmds(id)
  return id
endfunction "}}}
function! s:highlight.persist() dict abort  "{{{
  let id = s:get_pid()
  call s:set_autocmds(id)
  let s:quench_table[id] = self
  return id
endfunction "}}}

" for scheduled-quench "{{{
let s:quench_table = {}

if g:highlightedundo#fast_mode
  augroup highlightedundo-clear-highlight
    autocmd!
    autocmd WinLeave * call s:quench(-1)
  augroup END
endif

function! s:quench(id) abort  "{{{
  if g:highlightedundo#fast_mode
    call setmatches(filter(getmatches(), 'v:val.group !~# ''^Highlightedundo\(Add\|Change\|Delete\)$'''))
    if get(s:, 'timer_id', -1) >= 0
      call timer_stop(s:timer_id)
      unlet! s:timer_id
    endif
    let s:quench_table = {}
  else
    return s:quench_(a:id)
  endif
endfunction "}}}
function! s:quench_(id) abort  "{{{
  let options = s:shift_options()
  let highlight = s:get(a:id)
  try
    if highlight != {}
      call highlight.quench()
    endif
  catch /^Vim\%((\a\+)\)\=:E523/
    " NOTE: TextYankPost event sets "textlock"
    if highlight != {}
      call highlight.quench_timer(50)
    endif
    return 1
  finally
    unlet! s:quench_table[a:id]
    call timer_stop(a:id)
    call s:restore_options(options)
    redraw
  endtry
  call s:clear_autocmds()
endfunction "}}}
function! highlightedundo#highlight#cancel(...) abort "{{{
  if a:0 > 0
    let id_list = type(a:1) == s:type_list ? a:1 : a:000
  else
    let id_list = map(keys(s:quench_table), 'str2nr(v:val)')
  endif

  for id in id_list
    call s:quench(id)
  endfor
endfunction "}}}
function! s:get(id) abort "{{{
  return get(s:quench_table, a:id, {})
endfunction "}}}
let s:paused = []
function! s:quench_paused(...) abort "{{{
  if s:is_in_cmdline_window()
    return
  endif

  for highlight in s:paused
    call highlight.quench()
  endfor
  let s:paused = []
  augroup highlightedundo-pause-quenching
    autocmd!
  augroup END
endfunction "}}}
function! s:got_out_of_cmdwindow() abort "{{{
  augroup highlightedundo-pause-quenching
    autocmd!
    autocmd CursorMoved * call s:quench_paused()
  augroup END
endfunction "}}}

" ID for persistent highlights
let s:pid = 0
function! s:get_pid() abort "{{{
  if s:pid != -1/0
    let s:pid -= 1
  else
    let s:pid = -1
  endif
  return s:pid
endfunction "}}}

function! s:set_autocmds(id) abort "{{{
  augroup highlightedundo-highlight
    autocmd!
    " execute printf('autocmd TextChanged <buffer> call s:cancel_highlight(%s, "TextChanged")', a:id)
    execute printf('autocmd InsertEnter <buffer> call s:cancel_highlight(%s, "InsertEnter")', a:id)
    execute printf('autocmd BufUnload <buffer> call s:cancel_highlight(%s, "BufUnload")', a:id)
    execute printf('autocmd BufEnter * call s:switch_highlight(%s)', a:id)
  augroup END
endfunction "}}}
function! s:clear_autocmds() abort "{{{
  augroup highlightedundo-highlight
    autocmd!
  augroup END
endfunction "}}}
function! s:cancel_highlight(id, event) abort  "{{{
  let highlight = s:get(a:id)
  if highlight != {}
    call s:quench(a:id)
  endif
endfunction "}}}
function! s:switch_highlight(id) abort "{{{
  let highlight = s:get(a:id)
  if highlight != {} && highlight.winid == s:win_getid()
    if highlight.bufnr == bufnr('%')
      call highlight.show()
    else
      call highlight.quench()
    endif
  endif
endfunction "}}}
"}}}

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
function! s:highlight_order_blockwise(region) abort "{{{
  let view = winsaveview()
  let vcol_head = virtcol(a:region.head[1:2])
  if a:region.blockwidth == s:maxcol
    let vcol_tail = a:region.blockwidth
  else
    let vcol_tail = vcol_head + a:region.blockwidth - 1
  endif
  let order = []
  let order_list = []
  let n = 0
  if a:region.head != s:null_pos && a:region.tail != s:null_pos && s:is_equal_or_ahead(a:region.tail, a:region.head)
    for lnum in range(a:region.head[1], a:region.tail[1])
      call cursor(lnum, 1)
      execute printf('normal! %s|', vcol_head)
      let head = getpos('.')
      execute printf('normal! %s|', vcol_tail)
      let tail = getpos('.')
      let col = head[2]
      let len = tail[2] - head[2] + 1
      let order += [[lnum, col, len]]

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
  call winrestview(view)
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
function! s:saveregisters() abort "{{{
  let registers = {}
  let registers['0'] = s:getregister('0')
  let registers['1'] = s:getregister('1')
  let registers['2'] = s:getregister('2')
  let registers['3'] = s:getregister('3')
  let registers['4'] = s:getregister('4')
  let registers['5'] = s:getregister('5')
  let registers['6'] = s:getregister('6')
  let registers['7'] = s:getregister('7')
  let registers['8'] = s:getregister('8')
  let registers['9'] = s:getregister('9')
  let registers['"'] = s:getregister('"')
  if &clipboard =~# 'unnamed'
    let registers['*'] = s:getregister('*')
  endif
  if &clipboard =~# 'unnamedplus'
    let registers['+'] = s:getregister('+')
  endif
  return registers
endfunction "}}}
function! s:restoreregisters(registers) abort "{{{
  for [register, contains] in items(a:registers)
    call s:setregister(register, contains)
  endfor
endfunction "}}}
function! s:getregister(register) abort "{{{
  return [getreg(a:register), getregtype(a:register)]
endfunction "}}}
function! s:setregister(register, contains) abort "{{{
  let [value, options] = a:contains
  return setreg(a:register, value, options)
endfunction "}}}
function! s:v(v) abort  "{{{
  if a:v ==# 'char'
    let v = 'v'
  elseif a:v ==# 'line'
    let v = 'V'
  elseif a:v ==# 'block'
    let v = "\<C-v>"
  else
    let v = a:v
  endif
  return v
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
