require 'fig/statement'

module Fig; end

# Specifies the destination to put a dependency into.
class Fig::Statement::Retrieve < Fig::Statement
  attr_reader :var, :path

  def initialize(line_column, var, path)
    super(line_column)

    @var = var
    @path = path
  end

  def unparse(indent)
    "#{indent}retrieve #{var}->#{path}"
  end
end
