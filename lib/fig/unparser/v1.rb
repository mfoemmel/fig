require 'fig/unparser'
require 'fig/unparser/v0_ish'

module Fig; end
module Fig::Unparser; end

# Handles serializing of statements in the v1 grammar.
class Fig::Unparser::V1
  include Fig::Unparser
  include Fig::Unparser::V0Ish

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
end
