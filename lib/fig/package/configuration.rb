require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/command'

module Fig; end
class Fig::Package; end

class Fig::Package::Configuration
  attr_reader :name, :statements

  def initialize(name, statements)
    @name = name
    @statements = statements
  end

  def with_name(name)
    Configuration.new(name, statements)
  end

  def commands
    result = statements.select { |statement| statement.is_a?(Command) }
    result
  end

  def unparse(indent)
    unparse_statements(indent, "config #{@name}", @statements, 'end')
  end
end
