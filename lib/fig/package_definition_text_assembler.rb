require 'fig/unparser/v0'

module Fig; end

# Used for building packages for publishing.
class Fig::PackageDefinitionTextAssembler
  attr_reader :input_statements
  attr_reader :output_statements

  def initialize()
    @input_statements   = []
    @output_statements  = []
    @header_text        = []
    @footer_text        = []

    return
  end

  # Argument can either be a single Statement or an array of them.
  def add_input(statements)
    @input_statements << statements
    @input_statements.flatten!

    return
  end

  # Argument can either be a single Statement or an array of them.
  def add_output(statements)
    @output_statements << statements
    @output_statements.flatten!

    return
  end

  def asset_input_statements()
    return @input_statements.select { |statement| statement.is_asset? }
  end

  # Argument can be a single string or an array of strings
  def add_header(text)
    @header_text << text

    return
  end

  # Argument can be a single string or an array of strings
  def add_footer(text)
    @footer_text << text

    return
  end

  def assemble_package_definition()
    definition =
      [@header_text, unparse_statements(), @footer_text].flatten.join("\n")
    definition.gsub!(/\n{3,}/, "\n\n")
    definition.strip!
    definition << "\n"

    return definition
  end

  private

  def unparse_statements()
    unparser = Fig::Unparser::V0.new :emit_as_to_be_published

    return unparser.unparse(@output_statements)
  end
end
