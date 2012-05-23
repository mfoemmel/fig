require 'fig/user_input_error'

module Fig; end
class Fig::Command; end

# Bad command-line option.
class Fig::Command::OptionError < Fig::UserInputError
end
