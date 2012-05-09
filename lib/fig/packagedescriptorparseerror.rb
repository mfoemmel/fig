require 'fig/userinputerror'

module Fig
  # Could not determine some kind of information from a configuration file,
  class PackageDescriptorParseError < UserInputError
    attr_accessor :original_string

    def initialize(message, original_string)
      super(message)

      @file = original_string

      return
    end
  end
end
