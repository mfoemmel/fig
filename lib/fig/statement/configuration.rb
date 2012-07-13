require 'fig/statement'
require 'fig/statement/command'

module Fig; end

# A grouping of statements within a package.  May not be nested.
#
# Any processing of statements is guaranteed to hit any Overrides first.
class Fig::Statement::Configuration < Fig::Statement
  attr_reader :name, :statements

  def initialize(line_column, source_description, name, statements)
    super(line_column, source_description)

    @name = name

    overrides, others = statements.partition do
      |statement| statement.is_a?(Fig::Statement::Override)
    end

    @statements = [overrides, others].flatten
  end

  def command_statement
    return statements.find do
      |statement| statement.is_a?(Fig::Statement::Command)
    end
  end

  # Block will receive a Statement and the current statement containment level.
  def walk_statements(current_containment_level = 0, &block)
    containment_level = current_containment_level + 1

    @statements.each do |statement|
      yield statement, containment_level
      statement.walk_statements containment_level, &block
    end
  end

  def unparse(indent)
    unparse_statements(indent, "config #{@name}", @statements, 'end')
  end

  def minimum_grammar_version_required()
    return 0
  end

  private

  def unparse_statements(indent, prefix, statements, suffix)
    body =
      @statements.map {|statement| statement.unparse(indent + '  ') }.join("\n")
    if body.length > 0
      body << "\n"
    end

    return "\n#{indent}#{prefix}\n#{body}#{indent}#{suffix}"
  end
end
