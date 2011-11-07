require 'fig/userinputerror'

module Fig
  class URLAccessError < UserInputError
    def initialize(url)
      @url = url
    end
  end
end
