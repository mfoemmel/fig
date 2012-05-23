require 'fig/user_input_error'

module Fig
  # Configuration attempted to specify a URL outside of the whitelist.
  class URLAccessError < UserInputError
    attr_reader :urls, :descriptor

    def initialize(urls, descriptor)
      @urls       = urls
      @descriptor = descriptor
    end
  end
end
