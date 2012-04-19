require 'fig/statement'

module Fig; end

# Specifies the destination to put a dependency into.
class Fig::Statement::Retrieve < Fig::Statement
  attr_reader   :var, :path

  def initialize(line_column, var, path)
    super(line_column)

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
