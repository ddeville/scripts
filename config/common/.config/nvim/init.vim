" vim needs a posix shell and fish is not
if &shell =~# "fish$"
  set shell=bash
endif

set encoding=utf-8

" make sure that the env variables are set (or pick the default value)
if empty($XDG_CONFIG_HOME)
  let $XDG_CONFIG_HOME = $HOME . "/.config"
endif

if empty($XDG_DATA_HOME)
  let $XDG_DATA_HOME = $HOME . "/.local/share"
endif

if empty($XDG_STATE_HOME)
  let $XDG_STATE_HOME = $HOME . "/.local/state"
endif

" (use different folders for vim and nvim since formats can be incompatible...)
if has("nvim")
  let backup_path = $XDG_STATE_HOME . "/nvim/backup"
  let undo_path = $XDG_STATE_HOME . "/nvim/undo"
else
  let backup_path = $XDG_STATE_HOME . "/vim/backup"
  let undo_path = $XDG_STATE_HOME . "/vim/undo"
endif

" store swap and backup files under XDG state dir
if !isdirectory(backup_path)
  call mkdir(backup_path, "p", 0700)
endif
let &directory = backup_path . "//"
let &backupdir = backup_path . "//"

" permanent undo
if !isdirectory(undo_path)
  call mkdir(undo_path, "p", 0700)
endif
let &undodir = undo_path . "//"
set undofile

" get netrw and viminfo to store their history in the XDG state dir
let g:netrw_home = $XDG_STATE_HOME . '/vim'
if !has("nvim")
  set viminfo+=n$XDG_STATE_HOME/vim/viminfo
endif

" set leader to space instead of the default backslash
noremap <Space> <Nop>
let mapleader = "\<Space>"

" attempt to determine the file type based on name and content
filetype plugin indent on

" vim-plug plugins
call plug#begin($XDG_CONFIG_HOME . "/nvim/plugged")

  " vim & neovim
  Plug 'chriskempson/base16-vim'
  Plug 'dag/vim-fish'
  Plug 'fatih/vim-go'
  Plug 'itchyny/lightline.vim'
  Plug 'junegunn/fzf', { 'dir': $XDG_DATA_HOME . '/fzf', 'do': { -> fzf#install() } } | Plug 'junegunn/fzf.vim'
  Plug 'mhinz/vim-grepper'
  Plug 'mhinz/vim-startify'
  Plug 'rust-lang/rust.vim'
  Plug 'tpope/vim-commentary'
  Plug 'tpope/vim-eunuch'
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-git'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-rhubarb'
  Plug 'tpope/vim-sleuth'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-unimpaired'
  Plug 'tpope/vim-vinegar'
  Plug 'vimwiki/vimwiki'
  Plug 'machakann/vim-highlightedyank'
  Plug 'google/vim-maktaba'
  Plug 'google/vim-codefmt'
  Plug 'baskerville/vim-sxhkdrc'

  " neovim only
  if has("nvim-0.5")
    Plug 'hrsh7th/nvim-cmp'
    Plug 'hrsh7th/cmp-nvim-lsp' | Plug 'hrsh7th/cmp-buffer'| Plug 'hrsh7th/cmp-path' | Plug 'hrsh7th/cmp-nvim-lua'
    Plug 'hrsh7th/vim-vsnip' | Plug 'hrsh7th/cmp-vsnip'
    Plug 'kosayoda/nvim-lightbulb'
    Plug 'neovim/nvim-lspconfig'
    Plug 'nvim-lua/lsp_extensions.nvim'
    Plug 'nvim-lua/lsp-status.nvim'
    Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/popup.nvim' | Plug 'nvim-lua/plenary.nvim'
    Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
  endif

call plug#end()

" update and reload config
command! Config execute ":edit $MYVIMRC"
command! Reload execute "source $MYVIMRC"

" enable syntax highlighting
syntax enable

" syntax highlighting for embedded lua code in vim files
let g:vimsyn_embed = 'l'

" dark background is better
set background=dark

" setup base16 colorscheme
if filereadable(expand($XDG_STATE_HOME . "/base16/vimrc_background"))
  let base16colorspace = 256
  source $XDG_STATE_HOME/base16/vimrc_background
endif

" shorten the delay to transition to normal mode after pressing escape
set timeoutlen=1000 ttimeoutlen=0

" lower how long it takes for cursor hold to kick off (for code actions for example)
set updatetime=300

" allow switching between buffers without saving first
set hidden

" use 4 spaces instead of tabs
set shiftwidth=4
set softtabstop=4
set tabstop=4
set expandtab

" if no known file type keep the same indent as the current line
set autoindent

" set mouse support so that we can select text and tabs
if has("mouse")
  set mouse=a
endif

" backspace through anything in insert mode
set backspace=indent,eol,start

" highlight search results and start searching immediately
set hlsearch
set incsearch

" always show at least one line above/below the cursor (and 5 on each side if not wrapping)
set scrolloff=1
set sidescrolloff=5

" display the cursor position in the status line
set ruler

" display the line number on the left
set number

" show the diagnostic ui where the number goes
if has("nvim-0.5") || has("patch-8.1.1564")
  set signcolumn=number
else
  set signcolumn=yes
end

" display a column at 80 char
set colorcolumn=80

" highlight the current line
set cursorline

" always show the status line even when there is only one window
set laststatus=2

" autoload file changes
set autoread

" open new splits on right and bottom
set splitbelow
set splitright

" don't add an extra space when joining lines
set nojoinspaces

" no beeping
set vb t_vb=

" don't give |ins-completion-menu| messages.
set shortmess+=c

" trailing whitespace is bad
highlight WhiteSpaceEOL guibg=Red ctermbg=Red
augroup trialing_whitespace
autocmd!
autocmd InsertEnter * match WhiteSpaceEOL /\s\+\%#\@<!$/
autocmd InsertLeave * match WhiteSpaceEOL /\s\+$/
augroup END

" netrw
let g:netrw_localrmdir = "rm -r"
let g:netrw_liststyle = 3
let g:netrw_winsize = 85
let g:netrw_browse_split = 0

" ==> MAPPINGS

" disable arrow keys
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" search current selection in visual mode with */#
function! s:VSetSearch()
  let temp = @@
  norm! gvy
  let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
  let @@ = temp
endfunction
vnoremap * :<C-u>call <SID>VSetSearch()<CR>//<CR><c-o>
vnoremap # :<C-u>call <SID>VSetSearch()<CR>??<CR><c-o>

" move lines up and down when in visual mode
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" map screen redraw to also turn off search highlighting
nnoremap <C-l> :nohl<CR><C-l>

" make Y behave like D and C
nnoremap Y y$

" ==> HIGHLIGHTS

" diagnostic error messages in red
highlight LspDiagnosticsDefaultError guifg=Red ctermfg=Red
highlight LspDiagnosticsVirtualTextError guifg=Red ctermfg=Red
highlight LspDiagnosticsSignError guifg=Red ctermfg=Red
highlight LspDiagnosticsUnderlineError guifg=Red ctermfg=Red
" diagnostic warning messages in yellow
highlight LspDiagnosticsDefaultWarning guifg=Yellow ctermfg=Yellow
highlight LspDiagnosticsVirtualTextWarning guifg=Yellow ctermfg=Yellow
highlight LspDiagnosticsSignWarning guifg=Yellow ctermfg=Yellow
highlight LspDiagnosticsUnderlineWarning guifg=Red ctermfg=Red
" diagnostic info messages in white
highlight LspDiagnosticsDefaultInformation guifg=White ctermfg=White
highlight LspDiagnosticsVirtualTextInformation guifg=White ctermfg=White
highlight LspDiagnosticsSignInformation guifg=White ctermfg=White
highlight LspDiagnosticsUnderlineInformation guifg=White ctermfg=White
" diagnostic hint messages in gray
highlight LspDiagnosticsDefaultHint guifg=Gray ctermfg=Gray
highlight LspDiagnosticsVirtualTextHint guifg=Gray ctermfg=Gray
highlight LspDiagnosticsSignHint guifg=Gray ctermfg=Gray
highlight LspDiagnosticsUnderlineHint guifg=Gray ctermfg=Gray

" configure sign column for diagnostic messages
if has("nvim")
  sign define LspDiagnosticsSignError text=E texthl=LspDiagnosticsDefaultError
  sign define LspDiagnosticsSignWarning text=W texthl=LspDiagnosticsDefaultWarning
  sign define LspDiagnosticsSignInformation text=I texthl=LspDiagnosticsDefaultInformation
  sign define LspDiagnosticsSignHint text=H texthl=LspDiagnosticsDefaultHint
end

" nvim-cmp
highlight CmpItemAbbr guifg=Gray ctermfg=Gray
highlight CmpItemAbbrDeprecated guifg=Red ctermfg=Red
highlight CmpItemAbbrMatch guifg=Yellow ctermfg=Yellow
highlight CmpItemAbbrMatch gui=underline cterm=underline
highlight CmpItemAbbrMatchFuzzy guifg=Yellow ctermfg=Yellow
highlight CmpItemAbbrMatchFuzzy gui=underline cterm=underline
highlight CmpItemKind guifg=Green ctermfg=Green
highlight CmpItemMenu guifg=Magenta ctermfg=Magenta

" load main lua plugin
if has("nvim-0.5")
  lua require("ddeville")
end
