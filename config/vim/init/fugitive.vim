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
