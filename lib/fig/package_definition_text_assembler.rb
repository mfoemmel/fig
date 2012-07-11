require 'fig/statement_container'

module Fig; end

# Used for building packages for publishing.
class Fig::PackageDefinitionTextAssembler
  include Fig::StatementContainer

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
    statement_text = []

    output_statements.each do
      |statement|

      if statement.is_asset?
        # TODO: Dump this synthetic statement crap and get the
        # statement.asset_name call into the unparsing itself.
        statement_text <<
          statement.class.new(nil, nil, statement.asset_name, false).unparse('')
      else
        statement_text << statement.unparse('')
      end
    end

    return statement_text
  end
end
