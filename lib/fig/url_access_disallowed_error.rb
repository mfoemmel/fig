require 'fig/user_input_error'

module Fig
  # Package definition attempted to specify a URL outside of the whitelist.
  class URLAccessDisallowedError < UserInputError
    attr_reader :urls, :descriptor

    def initialize(urls, descriptor)
      @urls       = urls
      @descriptor = descriptor
    end
  end
end
