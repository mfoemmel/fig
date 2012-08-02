require 'fig/statement'

module Fig; end

# Specifies a default command that will be executed for a given Configuration
# if no command is specified on the command-line.
class Fig::Statement::Command < Fig::Statement
  attr_reader :command

  def initialize(line_column, source_description, command)
    super(line_column, source_description)

    @command = command
  end

  def unparse_as_version(unparser)
    return unparser.command(self)
  end

  def minimum_grammar_for_publishing()
    return 0
  end
end
