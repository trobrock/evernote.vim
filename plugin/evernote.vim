function! s:ListNotebooks()
  exec 'silent split evernote:something'
  ruby $evernote.listNotebooks
  setlocal buftype=nofile bufhidden=unload noswapfile
  setlocal nomodified
endfunction

function! s:ListNotes()
  let curline = getline('.')
  ruby $evernote.listNotes(VIM::evaluate('curline'))
endfunction

ruby << EOF
    require "ruby/evernote-vim/controller.rb"

    $evernote = EvernoteVim::Controller.new
EOF

map <C-e> :call <SID>ListNotebooks()<CR>
