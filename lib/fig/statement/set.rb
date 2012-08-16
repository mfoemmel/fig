require 'fig/statement'
require 'fig/statement/environment_variable'

module Fig; end

# A statement that sets the value of an environment variable.
class Fig::Statement::Set < Fig::Statement
  include Fig::Statement::EnvironmentVariable

  # We block quotes right now in order to allow for using them for
  # quoting later.
  VALUE_REGEX          = %r< \A [^\s\\'"]* \z >x
  ARGUMENT_DESCRIPTION =
    %q<The value must look like "NAME=VALUE"; VALUE cannot contain whitespace though it can be empty.>

  # Yields on error.
  def self.parse_name_value(combined)
    variable, value = combined.split('=')

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

  def statement_type()
    return 'set'
  end

  def is_environment_variable?()
    return true
  end

  def unparse_as_version(unparser)
    return unparser.set(self)
  end
end
