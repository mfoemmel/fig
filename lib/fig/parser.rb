# coding: utf-8

require 'set'

require 'fig/grammar/version_identification'
require 'fig/grammar/v0'
require 'fig/grammar/v1'
require 'fig/grammar/v2'
require 'fig/grammar_monkey_patches'
require 'fig/logging'
require 'fig/package_parse_error'
require 'fig/parser_package_build_state'
require 'fig/statement'
require 'fig/url'
require 'fig/url_access_disallowed_error'
require 'fig/user_input_error'

module Fig; end

# Parses .fig files (wrapping the Treetop-generated parser object) and deals
# with a few restrictions on them.
class Fig::Parser
  def initialize(application_config, check_include_versions)
    @application_config     = application_config
    @check_include_versions = check_include_versions
  end

  def parse_package(unparsed_package)
    version = get_grammar_version unparsed_package

    if version == 0
      return parse_v0 unparsed_package
    end

    return parse_v1_or_later version, unparsed_package
  end

  private

  PARSER_CLASS = {
    1 => Fig::Grammar::V1Parser,
    2 => Fig::Grammar::V2Parser,
  }

  # TODO: Remove this once stablized.
  @@seen_v2 = false

  def get_grammar_version(unparsed_package)
    version_parser = Fig::Grammar::VersionIdentificationParser.new()

    extended_description = unparsed_package.extended_source_description

    result = version_parser.parse(unparsed_package.unparsed_text)
    if result.nil?
      raise_parse_error(
        version_parser,
        unparsed_package.unparsed_text,
        extended_description
      )
    end

    statement = result.get_grammar_version(
      Fig::ParserPackageBuildState.new(
        nil, unparsed_package.descriptor, extended_description
      )
    )
    return 0 if not statement

    version = statement.version
    if version > 2
      raise Fig::PackageParseError.new(
        %Q<Don't know how to parse grammar version #{version}#{statement.position_string()}.>
      )
    end
    if version == 2 && ! @@seen_v2
      @@seen_v2 = true
      Fig::Logging.info(
        'Encountered v2 grammar.  This is experimental and subject to change without notice.'
      )
    end

    return version
  end

  def parse_v0(unparsed_package)
    stripped_text = unparsed_package.unparsed_text.gsub(/#.*$/, '') # Blech.

    v0_parser = Fig::Grammar::V0Parser.new

    return drive_treetop_parser(v0_parser, unparsed_package, stripped_text)
  end

  def parse_v1_or_later(version, unparsed_package)
    parser = PARSER_CLASS[version].new

    return drive_treetop_parser(
      parser,
      unparsed_package,
      unparsed_package.unparsed_text
    )
  end

  def drive_treetop_parser(
    parser, unparsed_package, cleaned_text # Ugh. V0 strips comments via regex.
  )
    # Extra space at the end because most of the rules in the grammar require
    # trailing whitespace.
    result = parser.parse(cleaned_text + ' ')

    extended_description = unparsed_package.extended_source_description

    if result.nil?
      raise_parse_error(parser, cleaned_text, extended_description)
    end

    package = result.to_package(
      unparsed_package,
      Fig::ParserPackageBuildState.new(
        parser.version, unparsed_package.descriptor, extended_description
      )
    )

    check_for_bad_urls(package, unparsed_package.descriptor)
    check_for_multiple_command_statements(package)
    check_for_missing_versions_on_include_statements(package)

    return package
  end

  def raise_parse_error(treetop_parser, text, extended_description)
    message = extended_description

    failure_reason = treetop_parser.failure_reason
    message << ": #{failure_reason}"
    if message.sub!( / after\s*\z/, %q< after '>)
      start = treetop_parser.failure_index - 20
      if start < 0
        start = 0
      else
        message << '...'
      end

      message << text[start, treetop_parser.failure_index]
      message << %q<'>
    end

    raise Fig::PackageParseError.new(message)
  end

  def check_for_bad_urls(package, descriptor)
    return if not @application_config

    bad_urls = []
    package.walk_statements do |statement|
      statement.urls.each do |url|
        # collect all bad urls in bad_urls
        next if not Fig::URL.is_url?(url)
        bad_urls << url if not @application_config.url_access_allowed?(url)
      end
    end

    raise Fig::URLAccessDisallowedError.new(bad_urls, descriptor) if not bad_urls.empty?

    return
  end

  def check_for_multiple_command_statements(package)
    command_processed = false
    package.walk_statements do |statement|
      if statement.is_a?(Fig::Statement::Command)
        if command_processed == true
          raise Fig::PackageParseError.new(
            %Q<Found a second "command" statement within a "config" block#{statement.position_string()}.>
          )
        end
        command_processed = true
      elsif statement.is_a?(Fig::Statement::Configuration)
        command_processed = false
      end
    end

    return
  end

  def check_for_missing_versions_on_include_statements(package)
    return if not @check_include_versions

    package.walk_statements do |statement|
      if statement.is_a?(Fig::Statement::Include)
        statement.complain_if_version_missing()
      end
    end

    return
  end
end
