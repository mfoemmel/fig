require 'fig/statement'

module Fig; end

# A statement that sets the value of an environment variable.
class Fig::Statement::Set < Fig::Statement
  VALUE_REGEX          = %r< \A \S* \z >x
  ARGUMENT_DESCRIPTION =
    %q<The value must look like "NAME=VALUE"; VALUE cannot contain whitespace though it can be empty.>

  # Yields on error.
  def self.parse_name_value(combined)
    variable, value = combined.split("=")

    if variable !~ ENVIRONMENT_VARIABLE_NAME_REGEX
      yield
    end

    value = '' if value.nil?
    if value !~ VALUE_REGEX
      yield
    end

    return [variable, value]
  end

  attr_reader :name, :value

  def initialize(line_column, source_description, name, value)
    super(line_column, source_description)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}set #{name}=#{value}"
  end
end
