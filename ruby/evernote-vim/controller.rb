require "rubygems"
require "evernote"
require "rexml/document"

module EvernoteVim
  class Controller
    def initialize
      @prevBuffer = []

      @consumerKey = "trobrock"
      @consumerSecret = "8f750bb98a7168c5"

      @evernoteHost = "sandbox.evernote.com"
      @userStoreUrl = "https://#{@evernoteHost}/edam/user"
      @noteStoreUrlBase = "https://#{@evernoteHost}/edam/note/"
    end

    def authenticate
      username = VIM::evaluate("g:evernote_vim_username")
      password = VIM::evaluate("g:evernote_vim_password")

      if username.empty?
        VIM::command("let user_input = input('Username: ')")
        username = VIM::evaluate("user_input")
        VIM::command("let g:evernote_vim_username = user_input")
      end
      if password.empty?
        VIM::command("let user_input = input('Password: ')")
        password = VIM::evaluate("user_input")
        VIM::command("let g:evernote_vim_password = user_input")
      end

      config = {
        :username => username,
        :password => password,
        :consumer_key => @consumerKey,
        :consumer_secret => @consumerSecret
      }
      userStore = Evernote::UserStore.new(@userStoreUrl, config)

      begin
        authResult = userStore.authenticate
      rescue Evernote::UserStore::AuthenticationFailure
        VIM::message("An error occurred while authenticating to Evernote")
        exit 1
      end

      @user = authResult.user
      @authToken = authResult.authenticationToken
    end

    def selectNotebook()
      notebook = VIM::evaluate('getline(".")')
      listNotes(notebook)
    end

    def selectNote()
      note = VIM::evaluate('getline(".")')
      openNote(note)
    end

    def listNotebooks
      authenticate_if_needed

      @noteStore = Evernote::NoteStore.new(@noteStoreUrlBase + @user.shardId)

      # Clear current buffer.
      while $curbuf.count > 1
        $curbuf.delete $curbuf.count
      end

      # Display list of notebooks in current buffer.
      @notebooks = @noteStore.listNotebooks(@authToken)
      @notebooks.each do |notebook|
        if notebook.defaultNotebook
          $curbuf.append(0, "* #{notebook.name} (default)")
        else
          $curbuf.append(0, "* #{notebook.name}")
        end
      end
      # VIM::Buffer.append adds an empty line after the appended line. Delete it.
      $curbuf.delete $curbuf.count

      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNotebook()<cr>'")
    end

    def listNotes(line)
      authenticate_if_needed

      notebook = line.gsub(/^(\* )/, '').gsub(/ \(default\)$/, '')
      notebook = @notebooks.detect { |n| n.name == notebook }
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.notebookGuid = notebook.guid

      @noteList = @noteStore.findNotes(@authToken, filter, 0, Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX)

      @prevBuffer << $curbuf.number
      VIM::command("q")
      VIM::command("silent 50vsplit evernote:notes")
      @noteList.notes.each do |note|
        $curbuf.append(0, note.title)
      end
      $curbuf.delete $curbuf.count

      VIM::command("setlocal buftype=nofile bufhidden=unload noswapfile")
      VIM::command("setlocal nomodifiable nomodified")
      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNote()<cr>'")
      VIM::command("map <silent> <buffer> <C-T> :ruby $evernote.previousScreen()<cr>")
    end

    def openNote(line)
      authenticate_if_needed

      @note = @noteList.notes.detect { |n| n.title == line }
      xmlContent = @noteStore.getNoteContent(@authToken, @note.guid)

      # Create new buffer to the right of current buffer.
      VIM::command("silent wincmd l")
      VIM::command("silent edit evernote:#{@note.title.gsub(/\s/, '-')}")

      # Parse XML and append it note buffer.
      doc = REXML::Document.new(xmlContent)
      $curbuf.append(0, get_text(doc.elements['en-note']))
      VIM::command("setlocal nomodified")
      VIM::command("au! BufWriteCmd <buffer> ruby $evernote.saveNote")
    end

    def saveNote
      content = ""
      for i in 1..$curbuf.count
        content += $curbuf[i] + "<br/>"
      end
      @note.content = '<?xml version="1.0" encoding="UTF-8"?>' +
        '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">' +
        "<en-note>#{content}</en-note>"
      @noteStore.updateNote(@authToken, @note)
    end

    def previousScreen
      VIM::command("buffer #{@prevBuffer.pop}")
    end

    private

    def authenticate_if_needed
      return if @authToken && @user
      authenticate
    end

    def get_text(element)
      all_text = element.inject("") do |memo, child|
        if child.is_a? REXML::Text
          memo += child.to_s + "\n"
        else
          memo += get_text(child)
        end
        memo
      end
      all_text
    end
  end
end
