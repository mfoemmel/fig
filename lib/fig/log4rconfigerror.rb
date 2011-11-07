require 'fig/userinputerror'

module Fig
  class Log4rConfigError < UserInputError
    def initialize(config_file, original_exception)
      super(
        %Q<Problem with #{config_file}: #{original_exception.message}>
      )

      @config_file = config_file
      @original_exception = original_exception
    end
  end
end
