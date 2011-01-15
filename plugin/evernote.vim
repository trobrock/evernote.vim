function! HelloWorld()
  exec 'silent split evernote:something'
  call RubyMsg()
  setlocal buftype=nofile bufhidden=unload noswapfile
  setlocal nomodified
endfunction

function! RubyMsg()
  ruby msg
endfunction

ruby << EOF
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

  def msg
    vb = VIM::Buffer.current

    consumerKey = "trobrock"
    consumerSecret = "8f750bb98a7168c5"

    evernoteHost = "sandbox.evernote.com"
    userStoreUrl = "https://#{evernoteHost}/edam/user"
    noteStoreUrlBase = "https://#{evernoteHost}/edam/note/"

    username = "trobrock"
    password = "testing"

    userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
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
                                          consumerKey, consumerSecret)
    rescue Evernote::EDAM::Error::EDAMUserException => ex
      # See http://www.evernote.com/about/developer/api/ref/UserStore.html#Fn_UserStore_authenticate
      parameter = ex.parameter
      errorCode = ex.errorCode
      errorText = Evernote::EDAM::Error::EDAMErrorCode::VALUE_MAP[errorCode]

      puts "Authentication failed (parameter: #{parameter} errorCode: #{errorText})"
      
      if (errorCode == Evernote::EDAM::Error::EDAMErrorCode::INVALID_AUTH)
        if (parameter == "consumerKey")
          if (consumerKey == "en-edamtest")
            puts "You must replace the variables consumerKey and consumerSecret with the values you received from Evernote."
          else
            puts "Your consumer key was not accepted by #{evernoteHost}"
          end
          puts "If you do not have an API Key from Evernote, you can request one from http://www.evernote.com/about/developer/api"
        elsif (parameter == "username")
          puts "You must authenticate using a username and password from #{evernoteHost}"
          if (evernoteHost != "www.evernote.com")
            puts "Note that your production Evernote account will not work on #{evernoteHost},"
            puts "you must register for a separate test account at https://#{evernoteHost}/Registration.action"
          end
        elsif (parameter == "password")
          puts "The password that you entered is incorrect"
        end
      end

      exit(1)
    end

    user = authResult.user
    authToken = authResult.authenticationToken

    noteStoreUrl = noteStoreUrlBase + user.shardId
    noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
    noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
    noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

    notebooks = noteStore.listNotebooks(authToken)
    defaultNotebook = notebooks[0]
    notebooks.each { |notebook| 
      vb.append(0, "  * #{notebook.name}")
      if (notebook.defaultNotebook)
        defaultNotebook = notebook
      end
    }

  end
EOF
