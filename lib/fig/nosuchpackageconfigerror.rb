require 'fig/packagedescriptor'
require 'fig/userinputerror'

module Fig
  # User specified a configuration for a Package that does not exist.
  class NoSuchPackageConfigError < UserInputError
    attr_accessor :descriptor

    def initialize(message, descriptor)
      super(message)

      @descriptor = descriptor
    end
  end
end
