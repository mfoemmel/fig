# coding: utf-8

require 'fig/package_descriptor'
require 'fig/user_input_error'

module Fig
  # User specified a configuration for a Package that does not exist.
  class NoSuchPackageConfigError < UserInputError
    attr_reader :descriptor
    attr_reader :package

    def initialize(message, descriptor, package)
      super(message)

      @descriptor = descriptor
      @package = package
    end
  end
end
