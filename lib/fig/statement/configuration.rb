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

  # Block will receive a Statement.
  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end
  end

  def unparse_as_version(unparser)
    return unparser.configuration(self)
  end

  def minimum_grammar_for_publishing()
    return 0
  end
end
