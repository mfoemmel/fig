require 'fig/statement'

module Fig; end

# A statement that specifies or modifies a path environment variable, e.g.
# "append", "path", "add" (though those are all synonyms).
class Fig::Statement::Path < Fig::Statement
  attr_reader :name, :value

  NAME_REGEX         = %r< \b \w+ \b >x
  VALUE_REGEX        = %r< [^;:"<>|\s]+ >x

  def initialize(line_column, source_description, name, value)
    super(line_column, source_description)

    @name = name
    @value = value
  end

  def unparse(indent)
    "#{indent}append #{name}=#{value}"
  end
end
