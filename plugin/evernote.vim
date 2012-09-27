"=============================================================================
" File: gist.vim
" Author: Trae Robrock <trobrock@gmail.com>, Aaron McGeever
" <aaron@outright.com.
" Last Change: 16-Jan-2011.
" Version: 0.1
" WebPage: http://github.com/trobrock/evernote-vim
" License: MIT
"
if !exists('g:evernote_vim_username')
  let g:evernote_vim_username = ''
endif

if !exists('g:evernote_vim_password')
  let g:evernote_vim_password = ''
endif

function! s:ListNotebooks()
  exec 'silent 50vsplit evernote:notebooks'
  ruby $evernote.listNotebooks
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodifiable nomodified
endfunction

ruby << EOF
  $LOAD_PATH.unshift(File.join(ENV['HOME'], '.vim', 'bundle', 'evernote.vim', 'ruby'))
  require "evernote-vim/controller"
  $evernote = EvernoteVim::Controller.new
EOF

map <Leader>ev :call <SID>ListNotebooks()<CR>
