require 'fig/statement'

module Fig; end

# A statement that specifies or modifies a path environment variable, e.g.
# "append", "path", "add" (though those are all synonyms).
class Fig::Statement::Path < Fig::Statement
  attr_reader :name, :value

  def initialize(line, column, name, value)
    super(line, column)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}append #{name}=#{value}"
  end
end
