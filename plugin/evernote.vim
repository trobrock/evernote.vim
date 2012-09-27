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

if !exists('g:evernote_vim_ruby_dir')
  let g:evernote_vim_ruby_dir = ''
endif

function! s:ListNotebooks()
  exec 'silent 50vsplit evernote:notebooks'
  ruby $evernote.listNotebooks
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodified
endfunction

ruby << EOF
  ruby_dir = VIM::evaluate("g:evernote_vim_ruby_dir").empty? ? \
             File.join(ENV['HOME'], '.vim', 'bundle', 'evernote.vim', 'ruby') : \
             VIM::evaluate("g:evernote_vim_ruby_dir")
  $LOAD_PATH.unshift(ruby_dir)
  require 'net/http'
  # hack to eliminate the SSL certificate verification notification
  class Net::HTTP
    alias_method :old_initialize, :initialize
    def initialize(*args)
      old_initialize(*args)
      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
  end
  Dir["#{ruby_dir}/evernote-vim/*.rb"].each {|file| require file }
  $evernote = EvernoteVim::Controller.new
EOF

map <Leader>ev :call <SID>ListNotebooks()<CR>
