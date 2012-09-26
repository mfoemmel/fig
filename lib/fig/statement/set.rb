require 'fig/statement'
require 'fig/statement/environment_variable'

module Fig; end

# A statement that sets the value of an environment variable.
class Fig::Statement::Set < Fig::Statement
  include Fig::Statement::EnvironmentVariable

  # Yields on error.
  def self.parse_name_value(combined, &error_block)
    variable, raw_value = seperate_name_and_value combined, &error_block

    return [variable, tokenize_value(raw_value, &error_block)]
  end

  def self.parse_v0_name_value(combined, &error_block)
    variable, raw_value = seperate_name_and_value combined, &error_block
    base_v0_value_validation(variable, raw_value, &error_block)
    return [variable, tokenize_value(raw_value, &error_block)]
  end

  def initialize(line_column, source_description, name, tokenized_value)
    super(line_column, source_description)

    @name = name
    @tokenized_value = tokenized_value
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

  private

  def minimum_grammar()
    return standard_minimum_grammar
  end
end
