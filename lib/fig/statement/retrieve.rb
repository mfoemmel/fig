require 'fig/statement'

module Fig; end

# Specifies that files from a package should be copied into the current
# directory when an environment variable has its value changed.
class Fig::Statement::Retrieve < Fig::Statement
  attr_reader   :var, :path

  def initialize(line_column, source_description, var, path)
    super(line_column, source_description)

    @var = var
    @path = path
  end

  def loaded_but_not_referenced?()
    return added_to_environment? && ! referenced?
  end

  def added_to_environment?()
    return @added_to_environment
  end

  def added_to_environment(yea_or_nay)
    @added_to_environment = yea_or_nay
  end

  def referenced?()
    return @referenced
  end

  def referenced(yea_or_nay)
    @referenced = yea_or_nay
  end

  def unparse(indent)
    "#{indent}retrieve #{var}->#{path}"
  end
end
