require 'fig/package_descriptor'
require 'fig/user_input_error'

module Fig
  # User specified a configuration for a Package that does not exist.
  class NoSuchPackageConfigError < UserInputError
    attr_reader :descriptor

    def initialize(message, descriptor)
      super(message)

      @descriptor = descriptor
    end
  end
end
