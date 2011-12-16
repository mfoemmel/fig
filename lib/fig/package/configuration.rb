require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/command'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# A grouping of statements within a configuration.  May not be nested.
class Fig::Package::Configuration
  include Fig::Package::Statement

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
      |statement| statement.is_a?(Fig::Package::Command)
    end
  end

  def walk_statements(&block)
    @statements.each do |statement|
      yield statement
      statement.walk_statements &block
    end
  end

  def unparse(indent)
    unparse_statements(indent, "config #{@name}", @statements, 'end')
  end
end
