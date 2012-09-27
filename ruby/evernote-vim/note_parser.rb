module EvernoteVim
  class NoteParser
    def initialize
      @content = [] # the array of lines representing a note
      @line = 0 # starting line index at 0
    end

    def tag_start(name, attrs)
    end

    def tag_end(name)
      @line += 1 if name == "br"
    end

    def text(str)
      @content[@line] = (@content[@line] || "") + str
    end

    def doctype(name, pub_sys, long_name, uri)
    end

    def xmldecl(version, encoding, standalone)
    end

    def get_content
      @content
    end
  end
end
