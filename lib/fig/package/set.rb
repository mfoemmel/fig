require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# A statement that sets the value of an environment variable.
class Fig::Package::Set
  include Fig::Package::Statement

  attr_reader :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}set #{name}=#{value}"
  end
end
