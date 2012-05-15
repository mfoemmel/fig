require 'fig/statement'

module Fig; end

# A statement that sets the value of an environment variable.
class Fig::Statement::Set < Fig::Statement
  attr_reader :name, :value

  NAME_REGEX         = %r< \A \w+ \z >x
  VALUE_REGEX        = %r< \A \S* \z >x

  def initialize(line_column, source_description, name, value)
    super(line_column, source_description)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}set #{name}=#{value}"
  end
end
