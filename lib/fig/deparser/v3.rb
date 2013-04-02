require 'fig/deparser'
require 'fig/deparser/v1_base'
require 'fig/deparser/v2_base'

module Fig; end
module Fig::Deparser; end

# Handles serializing of statements in the v3 grammar.
class Fig::Deparser::V3
  include Fig::Deparser
  include Fig::Deparser::V1Base
  include Fig::Deparser::V2Base

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

    @text << "grammar v3\n"

    return
  end

  def desired_install_path(statement)
    path = statement.path
    quote = (path.include?(%q<'>) && ! path.include?(%q<">)) ? %q<"> : %q<'>

    add_indent

    @text << 'desired-install-path '
    @text << quote
    @text << path.gsub('\\', ('\\' * 4)).gsub(quote, "\\\\#{quote}")
    @text << quote
    @text << "\n"

    return
  end

  def use_desired_install_paths(statement)
    add_indent

    @text << "use-desired-install-paths\n"

    return
  end

  def grammar_description()
    return 'v3'
  end
end
