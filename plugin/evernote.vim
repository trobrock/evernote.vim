"=============================================================================
" File: gist.vim
" Author: Trae Robrock <trobrock@gmail.com>, Aaron McGeever
" <aaron@outright.com.
" Last Change: 16-Jan-2011.
" Version: 0.1
" WebPage: http://github.com/trobrock/evernote-vim
" License: MIT
"
function! s:ListNotebooks()
  exec 'silent split evernote:notebooks'
  ruby $evernote.listNotebooks
  setlocal buftype=nofile bufhidden=unload noswapfile
  setlocal nomodified
endfunction

function! s:AcceptSelection()
  let curline = getline('.')
  ruby $evernote.acceptSelection(VIM::evaluate('curline'))
endfunction

ruby << EOF
    require "ruby/evernote-vim/controller.rb"

    $evernote = EvernoteVim::Controller.new
EOF

map <C-e> :call <SID>ListNotebooks()<CR>
