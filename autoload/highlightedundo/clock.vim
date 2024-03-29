" clock object - measuring elapsed time in a operation

let s:clock = {
      \   'started' : 0,
      \   'paused'  : 0,
      \   'zerotime': reltime(),
      \   'stoptime': reltime(),
      \   'losstime': 0,
      \ }
function! highlightedundo#clock#new() abort
  return deepcopy(s:clock)
endfunction


function! s:clock.start() dict abort
  if self.started
    if self.paused
      let self.losstime += str2float(reltimestr(reltime(self.stoptime)))
      let self.paused = 0
    endif
  else
    let self.zerotime = reltime()
    let self.started  = 1
  endif
endfunction


function! s:clock.pause() dict abort
  let self.stoptime = reltime()
  let self.paused   = 1
endfunction


function! s:clock.elapsed() dict abort
  if self.started
    let total = str2float(reltimestr(reltime(self.zerotime)))
    return floor((total - self.losstime)*1000)
  else
    return 0
  endif
endfunction


function! s:clock.stop() dict abort
  let self.started  = 0
  let self.paused   = 0
  let self.losstime = 0
endfunction


" vim:set ts=2 sts=2 sw=2:
