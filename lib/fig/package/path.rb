require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# A statement that specifies or modifies a path environment variable, e.g.
# "append", "path", "add" (though those are all synonyms).
class Fig::Package::Path
  include Fig::Package::Statement

  attr_reader :name, :value

  def initialize(name, value)
    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}append #{name}=#{value}"
  end
end
