require 'fig/package_descriptor'
require 'fig/unparser'

module Fig; end
module Fig::Unparser; end

# Handles serializing of statements in the v0 grammar.
class Fig::Unparser::V0
  include Fig::Unparser

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

  def command(statement)
    add_indent

    @text << %q<command ">
    @text << statement.command.first.to_double_quotable_string
    @text << %Q<"\n>

    return
  end

  def grammar_version(statement)
    add_indent

    # Comment out so that older clients don't have issues.
    @text << "# grammar v0\n"

    return
  end

  def retrieve(statement)
    add_indent

    @text << 'retrieve '
    @text << statement.variable
    @text << '->'
    @text << statement.tokenized_path.to_double_quotable_string
    @text << "\n"

    return
  end

  def grammar_description()
    return 'v0'
  end

  private

  def asset(keyword, statement)
    path  = asset_path statement
    quote = path =~ /[*?\[\]{}]/ ? '' : %q<">

    add_indent
    @text << keyword
    @text << ' '
    @text << quote
    @text << path
    @text << quote
    @text << "\n"

    return
  end

  def environment_variable(statement, keyword)
    add_indent

    @text << keyword
    @text << ' '
    @text << statement.name
    @text << '='
    @text << statement.tokenized_value.to_double_quotable_string
    @text << "\n"

    return
  end
end
