require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/command'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

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

  def commands
    result = statements.select do
      |statement| statement.is_a?(Fig::Package::Command)
    end
    result
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
