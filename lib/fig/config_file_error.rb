# coding: utf-8

require 'fig/user_input_error'

module Fig
  # Could not determine some kind of information from a configuration file,
  # whether .figrc, log4r, package.fig, etc.
  class ConfigFileError < UserInputError
    attr_reader :file

    def initialize(message, file)
      super(message)

      @file = file

      return
    end
  end
end
