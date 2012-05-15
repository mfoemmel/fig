require 'fig/userinputerror'

module Fig; end
class Fig::Command; end

# Bad command-line option.
class Fig::Command::OptionError < Fig::UserInputError
end
