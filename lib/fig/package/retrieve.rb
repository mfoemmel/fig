require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Retrieve
  attr_reader :var, :path

  def initialize(var, path)
    @var = var
    @path = path
  end

  def unparse(indent)
    "#{indent}retrieve #{var}->#{path}"
  end
end
