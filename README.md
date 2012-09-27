A vim plugin to view and edit Evernote notes 
#Current State
This is currently in very early stages of develoment; it is still using the official [Evernote sandbox](http://sandbox.evernote.com/) until there is a stable version that can read from Evernote.

In the [TODO.md](evernote.vim/blob/master/TODO.md) file there is a semi-up to date list of things that need done.

#Installation
* Ensure that your Vim has ruby baked-in.
  `vim --version | grep ruby` should show the `+ruby` flag
* Install the [evernote gem](http://rubygems.org/gems/evernote)
* Install the evernote.vim plugin as you would install any other Vim plugin. You can obviously use [Pathogen](https://github.com/tpope/vim-pathogen/).
* Add the following variables to your .vimrc:
  `let g:evernote_vim_username = "your_evernote_username"`
  `let g:evernote_vim_password = "your_evernote_password"`
  `let g:evernote_vim_ruby_dir = "full_path_to_the_evernote_vim_ruby_directory"`
For example:
  `let g:evernote_vim_ruby_dir = "/Users/evernotelover/.vim/bundle/evernote.vim/ruby"`

#Source Structure
[plugin/evernote.vim](evernote.vim/blob/master/plugin/evernote.vim) is just a small shim that loads [ruby/evernote-vim/controller.rb](evernote.vim/blob/master/ruby/evernote-vim/controller.rb), where the real work happens.
