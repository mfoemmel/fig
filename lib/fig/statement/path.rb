require 'fig/statement'
require 'fig/statement/environment_variable'

module Fig; end

# A statement that specifies or modifies a path environment variable, e.g.
# "append", "path", "add" (though those are all synonyms).
class Fig::Statement::Path < Fig::Statement
  include Fig::Statement::EnvironmentVariable

  # Yields on error.
  def self.parse_name_value(combined, &error_block)
    variable, raw_value = seperate_name_and_value combined, &error_block

    tokenized_value = tokenize_value(raw_value, &error_block)

    if tokenized_value.to_escaped_string.length < 1
      yield %Q<The value of path variable #{variable} is empty.>
      return
    end

    return [variable, tokenized_value]
  end

  def self.parse_v0_name_value(combined, &error_block)
    variable, raw_value = seperate_name_and_value combined, &error_block

    if raw_value.length < 1
      yield %Q<The value of path variable #{variable} is empty.>
      return
    end

    base_v0_value_validation(variable, raw_value, &error_block)

    if raw_value =~ /([;:<>|])/
      yield %Q<The value of path variable #{variable} (#{raw_value}) contains a "#{raw_value}" character.>
      return
    end

    return [variable, tokenize_value(raw_value, &error_block)]
  end

  def initialize(line_column, source_description, name, tokenized_value)
    super(line_column, source_description)

    @name = name
    @tokenized_value = tokenized_value
  end

  def statement_type()
    return 'path'
  end

  def is_environment_variable?()
    return true
  end

  def unparse_as_version(unparser)
    return unparser.path(self)
  end
end
