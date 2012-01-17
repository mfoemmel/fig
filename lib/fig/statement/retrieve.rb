require 'fig/logging'
require 'fig/packageerror'
require 'fig/statement'

module Fig; end

# Specifies the destination to put a dependency into.
class Fig::Statement::Retrieve
  include Fig::Statement

  attr_reader :var, :path

  def initialize(var, path)
    @var = var
    @path = path
  end

  def unparse(indent)
    "#{indent}retrieve #{var}->#{path}"
  end
end
