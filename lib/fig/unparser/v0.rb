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

  def unparse(statements)
    @text         = ''
    @indent_level = @initial_indent_level

    statements.each { |statement| statement.unparse_as_version(self) }

    text          = @text
    @text         = nil
    @indent_level = nil

    return text
  end

  def archive(statement)
    add_indent

    # TODO: This means that v0 can publish grammatically incorrect code given
    # --archive command-line option with glob characters.  This is fixable
    # without breaking old code.
    @text << %q<archive ">
    add_asset_path statement
    @text << %Q<"\n>

    return
  end

  def command(statement)
    add_indent

    @text << %q<command ">
    @text << statement.command
    @text << %Q<"\n>

    return
  end

  def configuration(configuration_statement)
    if ! @text.empty?
      @text << "\n"
    end

    add_indent
    @text << 'config '
    @text << configuration_statement.name
    @text << "\n"

    @indent_level += 1
    begin
      configuration_statement.statements.each do
        |statement|

        statement.unparse_as_version(self)
      end
    ensure
      @indent_level -= 1
    end

    add_indent
    @text << "end\n"

    return
  end

  def grammar_version(statement)
    add_indent

    # Comment out if v0 so that older clients don't have issues.
    @text << (statement.version == 0 ? '# ' : '')
    @text << 'grammar v'
    @text << statement.version.to_s
    @text << "\n"

    return
  end

  def include(statement)
    add_indent

    @text << 'include '
    @text << Fig::PackageDescriptor.format(
      statement.package_name, statement.version, statement.config_name
    )
    @text << "\n"

    return
  end

  def override(statement)
    add_indent

    @text << 'override '
    @text << Fig::PackageDescriptor.format(
      statement.package_name, statement.version, nil
    )
    @text << "\n"

    return
  end

  def path(statement)
    environment_variable(statement, 'append')

    return
  end

  def resource(statement)
    add_indent

    @text << 'resource '
    add_asset_path statement
    @text << "\n"

    return
  end

  def retrieve(statement)
    add_indent

    @text << 'retrieve '
    @text << statement.var
    @text << '->'
    @text << statement.path
    @text << "\n"

    return
  end

  def set(statement)
    environment_variable(statement, 'set')

    return
  end

  private

  def environment_variable(statement, keyword)
    add_indent

    @text << keyword
    @text << ' '
    @text << statement.name
    @text << '='
    @text << statement.value
    @text << "\n"

    return
  end

  def add_indent()
    @text << @indent_string * @indent_level

    return
  end

  def add_asset_path(statement)
    if @emit_as_input_or_to_be_published_values == :emit_as_input
      @text << statement.url
    else
      @text << statement.asset_name
    end

    return
  end
end
