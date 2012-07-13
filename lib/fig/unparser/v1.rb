require 'fig/unparser'

module Fig; end
module Fig::Unparser; end

# Handles serializing of statements in the v1 grammar.
class Fig::Unparser::V1
  def initialize(indent_string = ' ' * 2, initial_indent_level = 0)
    @indent_string        = indent_string
    @initial_indent_level = initial_indent_level

    return
  end
end
