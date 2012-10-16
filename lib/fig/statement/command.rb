require 'fig/statement'

module Fig; end

# Specifies a default command that will be executed for a given Configuration
# if no command is specified on the command-line.
class Fig::Statement::Command < Fig::Statement
  attr_reader :command


  def self.validate_and_process_escapes_in_argument(
    command_line_argument, &block
  )
    tokenizer = Fig::StringTokenizer.new TOKENIZING_SUBEXPRESSION_MATCHER, '@'

    return tokenizer.tokenize command_line_argument, &block
  end

  def initialize(line_column, source_description, command)
    super(line_column, source_description)

    @command = command
  end

  def statement_type()
    return 'command'
  end

  def unparse_as_version(unparser)
    return unparser.command(self)
  end

  def minimum_grammar_for_emitting_input()
    return minimum_grammar()
  end

  def minimum_grammar_for_publishing()
    return minimum_grammar()
  end

  private

  def minimum_grammar()
    if command.size > 1
      return [1, 'contains multiple components']
    end

    argument = command.first.to_escaped_string

    # Can't have octothorpes anywhere in v0 due to comment stripping via
    # regex.
    if argument =~ /#/
      return [1, 'contains a comment ("#") character']
    end

    if argument =~ /"/
      return [1, %Q<contains a double quote>]
    end

    return [0]
  end

  TOKENIZING_SUBEXPRESSION_MATCHER = [
    {
      :pattern => %r< \@ [a-zA-Z0-9_.-]* >x,
      :action =>
        lambda {
          |subexpression, error_block|

          Fig::TokenizedString::Token.new :package_path, subexpression[1..-1]
        }
    }
  ]
end
