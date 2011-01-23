require "digest/md5"
require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "Evernote/EDAM/user_store"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store"
require "Evernote/EDAM/limits_constants.rb"

module EvernoteVim
  class Controller
    def initialize
      @prevBuffer = []

      @consumerKey = "trobrock"
      @consumerSecret = "8f750bb98a7168c5"

      @evernoteHost = "sandbox.evernote.com"
      @userStoreUrl = "https://#{@evernoteHost}/edam/user"
      @noteStoreUrlBase = "https://#{@evernoteHost}/edam/note/"

      authenticate
    end

    def authenticate
      username = "trobrock"
      password = "testing"

      userStoreTransport = Thrift::HTTPClientTransport.new(@userStoreUrl)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

      versionOK = userStore.checkVersion("Ruby EDAMTest",
                                      Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                      Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
      if (!versionOK)
        put "EDAM version is out of date #{versionOK}"
        exit(1)
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

        if (errorCode == Evernote::EDAM::Error::EDAMErrorCode::INVALID_AUTH)
          if (parameter == "consumerKey")
            if (@consumerKey == "en-edamtest")
              puts "You must replace the variables consumerKey and consumerSecret with the values you received from Evernote."
            else
              puts "Your consumer key was not accepted by #{@evernoteHost}"
            end
            puts "If you do not have an API Key from Evernote, you can request one from http://www.evernote.com/about/developer/api"
          elsif (parameter == "username")
            puts "You must authenticate using a username and password from #{@evernoteHost}"
            if (@evernoteHost != "www.evernote.com")
              puts "Note that your production Evernote account will not work on #{@evernoteHost},"
              puts "you must register for a separate test account at https://#{@evernoteHost}/Registration.action"
            end
          elsif (parameter == "password")
            puts "The password that you entered is incorrect"
          end
        end

        exit(1)
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
      noteStoreUrl = @noteStoreUrlBase + @user.shardId
      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      @noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

      @notebooks = @noteStore.listNotebooks(@authToken)
      defaultNotebook = @notebooks[0]
      @notebooks.each { |notebook| 
        if (notebook.defaultNotebook)
          $curbuf.append(0, "* #{notebook.name} (default)")
          defaultNotebook = notebook
        else
          $curbuf.append(0, "* #{notebook.name}")
        end
      }

      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNotebook()<cr>'")
    end

    def listNotes(line)
      notebook = line.gsub(/^(\* )/, '').gsub(/\(default\)$/, '')
      notebook = @notebooks.detect { |n| n.name = notebook }
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.notebookGuid = notebook.guid

      begin
        @noteList = @noteStore.findNotes(@authToken,
                                       filter,
                                       0,
                                       Evernote::EDAM::Limits::EDAM_USER_NOTES_MAX)
      rescue Evernote::EDAM::Error::EDAMUserException => e
        puts e.inspect
      end

      @prevBuffer << $curbuf.number
      VIM::command("q")
      VIM::command("silent split evernote:notes")
      @noteList.notes.each do |note|
        $curbuf.append(0, note.title)
      end

      VIM::command("setlocal buftype=nofile bufhidden= noswapfile")
      VIM::command("setlocal nomodified")
      VIM::command("exec 'nnoremap <silent> <buffer> <cr> :ruby $evernote.selectNote()<cr>'")
      VIM::command("map <silent> <buffer> <C-T> :ruby $evernote.previousScreen()<cr>")
    end

    def openNote(line)
      note = @noteList.notes.detect { |n| n.title == line }
      content = @noteStore.getNoteContent(@authToken, note.guid)

      @prevBuffer << $curbuf.number
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
      puts "Saving..."
    end

    def previousScreen
      VIM::command("buffer #{@prevBuffer.pop}")
    end
  end
end
