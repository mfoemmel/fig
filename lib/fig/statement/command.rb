require 'fig/statement'

module Fig; end

# Specifies a default command that will be executed for a given Configuration
# if no command is specified on the command-line.
class Fig::Statement::Command < Fig::Statement
  attr_reader :command

  def initialize(line, column, command)
    super(line, column)

    @command = command
  end

  def unparse(indent)
    %Q<#{indent}command "#{@command}">
  end
end
