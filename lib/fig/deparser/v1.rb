require 'fig/deparser'
require 'fig/deparser/v1_base'

module Fig; end
module Fig::Deparser; end

# Handles serializing of statements in the v1 grammar.
class Fig::Deparser::V1
  include Fig::Deparser
  include Fig::Deparser::V1Base

  def initialize(
    emit_as_input_or_to_be_published_values,
    indent_string = ' ' * 2,
    initial_indent_level = 0
  )
    @emit_as_input_or_to_be_published_values =
      emit_as_input_or_to_be_published_values
    @indent_string        = indent_string
    @initial_indent_level = initial_indent_level

    return
  end

  def grammar_version(statement)
    add_indent

    @text << "grammar v1\n"

    return
  end

  def grammar_description()
    return 'v1'
  end
end
