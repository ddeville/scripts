" insert an RFC 3339 date
function! DateRfc3339()
    let format = "+\%Y-\%m-\%dT\%H:\%M:\%SZ"
    let cmd = "/bin/date -u " . shellescape(format)
    let result = substitute(system(cmd), "[\]\|[[:cntrl:]]", '', 'g')
    " Append space + result to current line without moving cursor.
    call setline(line('.'), getline('.') . ' ' . result)
endfunction

" search current selection in visual mode with */#
function! s:VSetSearch()
    let temp = @@
    norm! gvy
    let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
    let @@ = temp
endfunction
vnoremap * :<C-u>call <SID>VSetSearch()<CR>//<CR><c-o>
vnoremap # :<C-u>call <SID>VSetSearch()<CR>??<CR><c-o>

" fugitive extension to get `:Gbrowse` to print the sourcegraph link
function! DropboxSourcegraphURL(opts) abort
    let repo = matchstr(a:opts.remote, "^git@git.sjc.dropbox.com:\zs.*\ze$")
    if repo ==# ''
        let repo = matchstr(a:opts.remote, "^ssh://git@git.sjc.dropbox.com/\zs.*\ze$")
        if repo ==# ''
            return ''
        endif
    endif
    let url = "https://sourcegraph.pp.dropbox.com/" . repo
    let url .= "@" . a:opts.repo.rev_parse(a:opts.commit)
    let url .= "/-/blob/" . a:opts.path
    if a:opts.line1
        let url .= "#L" . a:opts.line1
    endif
    return url
endfunction
if !exists("g:fugitive_browse_handlers")
    let g:fugitive_browse_handlers = []
endif
if index(g:fugitive_browse_handlers, function("DropboxSourcegraphURL")) < 0
    call insert(g:fugitive_browse_handlers, function("DropboxSourcegraphURL"))
endif

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
