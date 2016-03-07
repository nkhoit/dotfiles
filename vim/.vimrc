set nocompatible
syntax on
set hidden
set showmode
set wildmenu
set winaltkeys=no

if has("gui_running")
  if has("gui_gtk2")
    set guifont=Inconsolata\ 12
  elseif has("gui_macvim")
    set guifont=Menlo\ Regular:h14
  elseif has("gui_win32")
    set guifont=Consolas:h11:cANSI
  endif
endif

set clipboard=unnamedplus

" Change map leader
let mapleader = ","
let g:mapleader = ","

" Fast saving
nmap <leader>w :w!<cr>

" Quick access to vimrc
nmap <silent> ,ev :e $MYVIMRC<cr>
nmap <silent> ,sv :so $MYVIMRC<cr>

" Map up and down keys
map j gj
map k gk

" Plugins
if filereadable($HOME.'/.vim/bundle/Vundle.vim/autoload/vundle.vim')
  filetype off
  set rtp+=~/.vim/bundle/Vundle.vim
  call vundle#begin()

  Plugin 'gmarik/Vundle.vim'
  Plugin 'tpope/vim-fugitive'
  Plugin 'L9'
  Plugin 'flazz/vim-colorschemes'
  Plugin 'sudar/vim-arduino-syntax'
  Plugin 'jwhitley/vim-matchit'
  Plugin 'MarcWeber/vim-addon-mw-utils'
  Plugin 'tomtom/tlib_vim'
  Plugin 'garbas/vim-snipmate'
  Plugin 'honza/vim-snippets'
  Plugin 'tpope/vim-surround'
  Plugin 'scrooloose/nerdtree'
  Plugin 'jistr/vim-nerdtree-tabs'
  Plugin 'kien/ctrlp.vim'
  Plugin 'ervandew/supertab'
  Plugin 'davidhalter/jedi-vim'
  Plugin 'terryma/vim-multiple-cursors'
  Plugin 'scrooloose/syntastic'
  Plugin 'itchyny/lightline.vim'
  Plugin 'cocopon/lightline-hybrid.vim'
  Plugin 'fholgado/minibufexpl.vim'
  Plugin 'rainux/vim-desert-warm-256'
  Plugin 'fatih/vim-go'
  Plugin 'tclem/vim-arduino'
  Plugin 'jpo/vim-railscasts-theme'
  Plugin 'scrooloose/nerdcommenter'
  Plugin 'majutsushi/tagbar'

  call vundle#end()
  filetype plugin indent on
endif

" Command line height
set ch=1

" Allow backspace over indent, eol, and start of insert
set backspace=2

" Status line
set laststatus=2

" Hide mouse while typing
set mousehide

" History and search
set history=100
set complete=.,w,b,t
set wrapscan
set incsearch

" Cursor line
set cursorline
hi CursorLine term=bold cterm=bold guibg=Grey40

" No backup files
set nobackup
set nowb
set noswapfile

" Tab behaviour
set expandtab
set smarttab
set shiftwidth=4
set tabstop=4
set ai
set si
set wrap

" Ruler and line number
"set colorcolumn=80
set number

" Colorscheme
set t_Co=256
colorscheme railscasts

" Taglist
nmap <F8> :TagbarToggle<CR>

" NERDTree
:map <F5> :NERDTreeToggle<CR>
let NERDTreeShowHidden=0

" Mouse
set mouse=a

" CtrlP
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

" Lightline
let g:lightline = {}
let g:lightline.colorscheme = 'hybrid'
