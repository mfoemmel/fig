require 'fig/logging'
require 'fig/packageerror'
require 'fig/statement'
require 'fig/statement/command'

module Fig; end

# A grouping of statements within a configuration.  May not be nested.
class Fig::Statement::Configuration
  include Fig::Statement

  attr_reader :name, :statements

  def initialize(name, statements)
    @name = name
    @statements = statements
  end

  def with_name(name)
    Configuration.new(name, statements)
  end

  def command
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

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(repository, package, configuration, &block)
    @statements.each do |statement|
      yield package, self, statement
      statement.walk_statements_following_package_dependencies(
        repository, package, self, &block
      )
    end

    return
  end

  def unparse(indent)
    unparse_statements(indent, "config #{@name}", @statements, 'end')
  end
end
