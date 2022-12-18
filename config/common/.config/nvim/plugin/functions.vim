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

" delete any file in the given folder that is older than X days
function FolderCleanup(path, days)
  let l:path = expand(a:path)
  if isdirectory(l:path)
    for file in globpath(l:path, '*', 1, 1)
      if localtime() > getftime(file) + 86400 * a:days && delete(file) != 0
        echo "FolderCleanup(): Error deleting '" . file . "'"
      endif
    endfor
  else
    echo "FolderCleanup(): Directory '" . l:path . "' not found"
  endif
endfunction

" remove undo files which have not been modified for 60 days
call FolderCleanup(&undodir, 60)
