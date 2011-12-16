require 'fig/userinputerror'

module Fig
  # Configuration attempted to specify a URL outside of the whitelist.
  class URLAccessError < UserInputError
    attr_reader :urls, :package, :version

    def initialize(urls, package, version)
      @urls = urls
      @package = package
      @version = version
    end
  end
end
