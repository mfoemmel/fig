require 'fig/statement'
require 'fig/statement/command'

module Fig; end

# A grouping of statements within a configuration.  May not be nested.
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

  # Block will receive a Statement.
  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end
  end

  def unparse(indent)
    unparse_statements(indent, "config #{@name}", @statements, 'end')
  end

  private

  def unparse_statements(indent, prefix, statements, suffix)
    body =
      @statements.map {|statement| statement.unparse(indent + '  ') }.join("\n")

    return ["\n#{indent}#{prefix}", body, "#{indent}#{suffix}"].join("\n")
  end
end
