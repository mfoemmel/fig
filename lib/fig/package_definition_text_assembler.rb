# coding: utf-8

require 'fig/deparser'
require 'fig/deparser/v0'
require 'fig/deparser/v1'
require 'fig/deparser/v2'
require 'fig/statement/grammar_version'

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
  def add_output(*statements)
    # Version gets determined by other statements, not by existing grammar.
    @output_statements <<
      statements.flatten.reject { |s| s.is_a? Fig::Statement::GrammarVersion }

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
    unparsed_statements, explanations = deparse_statements()
    definition =
      [@header_text, unparsed_statements, @footer_text].flatten.join("\n")
    definition.gsub!(/\n{3,}/, "\n\n")
    definition.strip!
    definition << "\n"

    return definition, explanations
  end

  private

  def deparse_statements()
    deparser_class, explanations = Fig::Deparser.class_for_statements(
      @output_statements, @emit_as_input_or_to_be_published_values
    )

    grammar_statement =
      Fig::Statement::GrammarVersion.new(
        nil,
        %Q<[synthetic statement created in #{__FILE__} line #{__LINE__}]>,
        %q<Fake grammar version that shouldn't be used because the Deparser should determine what gets emitted.>
      )

    deparser = deparser_class.new @emit_as_input_or_to_be_published_values
    text = deparser.deparse( [grammar_statement] + @output_statements )

    explanations.unshift(
      "Publishing using the #{deparser.grammar_description} grammar."
    )

    return text, explanations
  end
end
