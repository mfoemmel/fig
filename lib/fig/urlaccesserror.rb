require 'fig/userinputerror'

module Fig
  class URLAccessError < UserInputError
    attr_reader :urls, :package, :version

    def initialize(urls, package, version)
      @urls = urls
      @package = package
      @version = version
    end
  end
end
