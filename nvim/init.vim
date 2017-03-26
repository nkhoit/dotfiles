syntax enable
filetype plugin indent on
let mapleader = ","
let g:mapleader = ","
imap jj <ESC>

" Install Plugins using vim-plug
" https://github.com/junegunn/vim-plug
call plug#begin('~/.config/nvim/plugged')
Plug 'rainux/vim-desert-warm-256'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/nerdcommenter'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
"Plug 'davidhalter/jedi-vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'ervandew/supertab'
Plug 'majutsushi/tagbar'
Plug 'terryma/vim-multiple-cursors'
Plug 'tpope/vim-sleuth'
Plug 'vim-scripts/Conque-GDB'
Plug 'craigemery/vim-autotag'
Plug 'fholgado/minibufexpl.vim'
call plug#end()

"
" Plugin Setup
"

" Deoplete
let g:deoplete#enable_at_startup = 1
let g:deoplete#file#enable_buffer_path = 1

" NERDTree
map <leader>p :NERDTreeToggle<cr>
let NERDTreeShowBookmarks = 0
let NERDChristmasTree = 1
let NERDTreeWinPos = "left"
let NERDTreeHijackNetrw = 1
let NERDTreeQuitOnOpen = 1
let NERDTreeWinSize = 50 
let NERDTreeChDirMode = 2
let NERDTreeDirArrows = 1

" Conque
let g:ConqueTerm_Color = 2         " 1: strip color after 200 lines, 2: always with color
let g:ConqueTerm_CloseOnEnd = 1    " close conque when program ends running
let g:ConqueTerm_StartMessages = 0 " display warning messages if conqueTerm is configured incorrectly  
let g:ConqueGdb_Leader='\'
" TagBar
nmap <leader>t :TagbarToggle<CR>

" Jedi-VIM 
" Don't mess up undo history
let g:jedi#show_call_signatures = "0"


" SuperTab configuration
"let g:SuperTabDefaultCompletionType = "<c-x><c-u>"
function! Completefunc(findstart, base)
    return "\<c-x>\<c-p>"
endfunction

" Python stuff
syntax enable
set number showmatch
set shiftwidth=4 tabstop=4 softtabstop=4 expandtab autoindent
let python_highlight_all = 1
let g:python2_host_prog = '/usr/local/bin/python'
let g:python3_host_prog = '/usr/local/bin/python3'

" Colorscheme
set t_Co=256
set background=dark
colorscheme desert-warm-256
highlight clear SignColumn
highlight CursorLine term=NONE cterm=NONE ctermbg=236

" General Settings
set modelines=0
set history=1000
set nobackup
set nowritebackup
set noswapfile
set autoread
set undofile
set title
set encoding=utf-8
set scrolloff=3
set autoindent
set smartindent
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set visualbell
set cursorline
set ttyfast
"set lazyredraw
set ruler
set backspace=indent,eol,start
set laststatus=2
set number
set previewheight=20


"  ---------------------------------------------------------------------------
"  Text Formatting
"  ---------------------------------------------------------------------------

set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set shiftround

set wrap
set formatoptions=n

"  ---------------------------------------------------------------------------
"  Misc
"  ---------------------------------------------------------------------------

set tildeop

"  ---------------------------------------------------------------------------
"  Mappings
"  ---------------------------------------------------------------------------

" yank to system clipboard
vnoremap yy :w !xclip -selection clipboard<CR><CR>
set clipboard=unnamedplus
" Searching / moving
nnoremap / /\v
vnoremap / /\v
set ignorecase
set smartcase
set incsearch
set showmatch
" set nohlsearch

hi Search ctermfg=NONE ctermbg=NONE cterm=underline

" Toggle search highlighting
noremap <F4> :set hlsearch! hlsearch?<CR>

" search (forwards), drops a mark first
nmap <space> /
" search (backwards), drops a mark first
map <c-space> ?

" Center screen when scrolling search results
nmap n nzz
nmap N Nzz


