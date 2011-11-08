require 'fig/userinputerror'

module Fig
  # Could not determine some kind of information from a configuration file,
  # whether .figrc, log4r, package.fig, etc.
  class ConfigFileError < UserInputError
    def initialize(message, file)
      super(message)

      @file = file

      return
    end
  end
end
