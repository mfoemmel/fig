require 'fig/user_input_error'

module Fig
  # Could not turn a string into a PackageDescriptor.
  class PackageDescriptorParseError < UserInputError
    attr_accessor :original_string

    def initialize(message, original_string)
      super(message)

      @file = original_string

      return
    end
  end
end
