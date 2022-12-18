" insert an RFC 3339 date
function! DateRfc3339()
  let format = "+\%Y-\%m-\%dT\%H:\%M:\%SZ"
  let cmd = "/bin/date -u " . shellescape(format)
  let result = substitute(system(cmd), "[\]\|[[:cntrl:]]", '', 'g')
  " Append space + result to current line without moving cursor.
  call setline(line('.'), getline('.') . ' ' . result)
endfunction

" insert a todo
function! Todo()
  " Append space + todo to current line without moving cursor.
  call setline(line('.'), getline('.') . ' ' . "TODO(damien)")
endfunction
