require "rubygems"
require "digest/md5"
require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "evernote"

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

      userStoreTransport = Thrift::HTTPClientTransport.new(@userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

      versionOK = userStore.checkVersion("Ruby EDAMTest",
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                         Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      if !versionOK
        put "EDAM version is out of date #{versionOK}"
        exit 1
      end

      # Authenticate the user
      begin
        authResult = userStore.authenticate(username, password,
                                            @consumerKey, @consumerSecret)
      rescue Evernote::EDAM::Error::EDAMUserException => ex
        # See http://www.evernote.com/about/developer/api/ref/UserStore.html#Fn_UserStore_authenticate
        parameter = ex.parameter
        errorCode = ex.errorCode
        errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]

        puts "Authentication failed (parameter: #{parameter} errorCode: #{errorText})"

        if errorCode == Evernote::EDAM::Error::EDAMErrorCode::INVALID_AUTH
          if parameter == "consumerKey"
            if @consumerKey == "en-edamtest"
              puts "You must replace the variables consumerKey and consumerSecret with the values you received from Evernote."
            else
              puts "Your consumer key was not accepted by #{@evernoteHost}"
            end
            puts "If you do not have an API Key from Evernote, you can request one from http://www.evernote.com/about/developer/api"
          elsif parameter == "username"
            puts "You must authenticate using a username and password from #{@evernoteHost}"
            if @evernoteHost != "www.evernote.com"
              puts "Note that your production Evernote account will not work on #{@evernoteHost},"
              puts "you must register for a separate test account at https://#{@evernoteHost}/Registration.action"
            end
          elsif parameter == "password"
            puts "The password that you entered is incorrect"
          end
        end

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

      noteStoreUrl = @noteStoreUrlBase + @user.shardId
      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

      # Clear current buffer.
=begin
      for i in 1..$curbuf.length
        $curbuf.delete(i)
      end
=end

      # Append notebooks to current buffer.
      @notebooks = @noteStore.listNotebooks(@authToken)
      @notebooks.each do |notebook|
        if notebook.defaultNotebook
          $curbuf.append(0, "* #{notebook.name} (default)")
        else
          $curbuf.append(0, "* #{notebook.name}")
        end
      end

      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNotebook()<cr>'")
    end

    def listNotes(line)
      authenticate_if_needed

      notebook = line.gsub(/^(\* )/, '').gsub(/\(default\)$/, '')
      notebook = @notebooks.detect { |n| n.name == notebook }
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.notebookGuid = notebook.guid

      @noteList = @noteStore.findNotes(@authToken, filter, 0, Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX)

      @prevBuffer << $curbuf.number
      VIM::command("q")
      VIM::command("silent split evernote:notes")
      @noteList.notes.each do |note|
        $curbuf.append(0, note.title)
      end

      VIM::command("setlocal buftype=nofile bufhidden=unload noswapfile")
      VIM::command("setlocal nomodified")
      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNote()<cr>'")
      VIM::command("map <silent> <buffer> <C-T> :ruby $evernote.previousScreen()<cr>")
    end

    def openNote(line)
      authenticate_if_needed

      note = @noteList.notes.detect { |n| n.title == line }
      content = @noteStore.getNoteContent(@authToken, note.guid)

      # Create a new buffer
      VIM::command("silent split evernote:#{note.title.gsub(/\s/, '-')}")

      # Append Note Content
      content = /<en-note>(.+)<\/en-note>/.match(content)[1]
      content = content.gsub(/<br( \/)?>/, "\n").gsub(/<([a-z\-\/]+)>/i, '')

      $curbuf.append(0, content)
      VIM::command("setlocal nomodified")
      VIM::command("au! BufWriteCmd <buffer> ruby $evernote.saveNote")
    end

    def saveNote
      puts "Saving... Not implemented yet"
    end

    def previousScreen
      VIM::command("buffer #{@prevBuffer.pop}")
    end

    private

    def authenticate_if_needed
      return if @authToken && @user
      authenticate
    end
  end
end
