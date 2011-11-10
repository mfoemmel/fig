require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Set
  attr_reader :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}set #{name}=#{value}"
  end
end
