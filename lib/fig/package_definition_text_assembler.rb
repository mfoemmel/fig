require 'fig/statement/grammar_version'
require 'fig/unparser/v0'
require 'fig/unparser/v1'

module Fig; end

# Used for building packages for publishing.
class Fig::PackageDefinitionTextAssembler
  attr_reader :input_statements
  attr_reader :output_statements

  def initialize(emit_as_input_or_to_be_published_values)
    @emit_as_input_or_to_be_published_values =
      emit_as_input_or_to_be_published_values

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

    # Version gets determined by other statements, not by existing grammar.
    @output_statements.reject! { |s| s.is_a? Fig::Statement::GrammarVersion }

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
    versions = get_statement_minimum_versions
    version = versions.max || 0

    unparser_class = nil
    if version == 1
      unparser_class = Fig::Unparser::V1
    else
      unparser_class = Fig::Unparser::V0
    end

    grammar_statement =
      Fig::Statement::GrammarVersion.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        0 # Grammar version
      )

    unparser = unparser_class.new @emit_as_input_or_to_be_published_values
    text = unparser.unparse( [grammar_statement] + @output_statements )

    # TODO: Until v1 grammar handling is done, ensure we don't emit anything
    # old fig versions cannot handle.
    if version != 0 && ! ENV['FIG_ALLOW_NON_V0_GRAMMAR']
      raise "Reached a point where something could not be represented by the v0 grammar. Bailing out.\n\nWould have attempted:\n#{text}"
    end

    return text
  end

  def get_statement_minimum_versions()
    if @emit_as_input_or_to_be_published_values == :emit_as_input
      return @output_statements.map {|s| s.minimum_grammar_for_emitting_input}
    end

    return @output_statements.map {|s| s.minimum_grammar_for_publishing}
  end
end
