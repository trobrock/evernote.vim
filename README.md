A vim plugin to edit Evernote notes

#Current State
This is currently in very early stages of develoment; it is still using the official [Evernote sandbox](http://sandbox.evernote.com/) until there is a stable version that can read from Evernote.

In the [TODO.md](evernote.vim/blob/master/TODO.md) file there is a semi-up to date list of things that need done.

#Requirements
* vim with ruby baked-in
* the [evernote gem](http://rubygems.org/gems/evernote)

#Source Structure
[plugin/evernote.vim](evernote.vim/blob/master/plugin/evernote.vim) is just a small shim that loads [ruby/evernote-vim/controller.rb](evernote.vim/blob/master/ruby/evernote-vim/controller.rb), where the real work happens.
                                                                       
                                                                      