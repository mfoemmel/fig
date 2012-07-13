require 'fig/user_input_error'

module Fig
  # A problem with configuring Log4r.
  class Log4rConfigError < UserInputError
    attr_reader :config_file, :original_exception

    def initialize(config_file, original_exception)
      super(
        %Q<Problem with #{config_file}: #{original_exception.message}>
      )

      @config_file = config_file
      @original_exception = original_exception
    end
  end
end
