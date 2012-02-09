require 'fig/statement'

module Fig; end

# A statement that sets the value of an environment variable.
class Fig::Statement::Set < Fig::Statement
  attr_reader :name, :value

  def initialize(line, column, name, value)
    super(line, column)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}set #{name}=#{value}"
  end
end
