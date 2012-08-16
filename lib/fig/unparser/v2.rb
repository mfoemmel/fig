require 'fig/unparser'

module Fig; end
module Fig::Unparser; end

# Handles serializing of statements in the v2 grammar.
class Fig::Unparser::V2
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
    @text << statement.command
    @text << %Q<"\n>

    return
  end

  def grammar_version(statement)
    add_indent

    @text << "grammar v2\n"

    return
  end

  def grammar_description()
    return 'v2'
  end

  private

  def asset(keyword, statement)
    quote = %q<'>
    path  = asset_path statement

    if statement.glob_if_not_url?
      quote = %q<">
      path = path.gsub(/\\/, ('\\' * 4))
    end

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
    # TODO: temporarily hack v0 grammar in here so we can test asset
    # statements; proper implementation once asset statements are done.
    add_indent

    @text << keyword
    @text << ' '
    @text << statement.name
    @text << '='
    @text << statement.value
    @text << "\n"

    return
  end
end
