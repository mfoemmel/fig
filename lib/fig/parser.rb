require 'set'

require 'fig/grammar/version_identification'
require 'fig/grammar/v0'
require 'fig/grammar/v1'
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
  # Keywords that we really want to lock down.
  def self.strict_keyword?(string)
    # "config" is considered too useful for users, so we allow that where we
    # restrict other keywords.
    return false if string == 'config'

    return keyword? string
  end

  def self.keyword?(string)
    return KEYWORDS.include? string
  end

  def initialize(application_config, check_include_versions)
    @application_config     = application_config
    @check_include_versions = check_include_versions
  end

  def parse_package(descriptor, directory, source_description, unparsed_text)
    version = get_grammar_version(
      descriptor, directory, source_description, unparsed_text
    )

    if version == 0
      return parse_v0(descriptor, directory, source_description, unparsed_text)
    end

    return parse_v1(descriptor, directory, source_description, unparsed_text)
  end

  private

  KEYWORDS = Set.new
  KEYWORDS << 'add'
  KEYWORDS << 'append'
  KEYWORDS << 'archive'
  KEYWORDS << 'command'
  KEYWORDS << 'config'
  KEYWORDS << 'end'
  KEYWORDS << 'include'
  KEYWORDS << 'override'
  KEYWORDS << 'path'
  KEYWORDS << 'resource'
  KEYWORDS << 'retrieve'
  KEYWORDS << 'set'


  def get_grammar_version(
    descriptor, directory, source_description, unparsed_text
  )
    version_parser = Fig::Grammar::VersionIdentificationParser.new()

    extended_description =
      extend_source_description(directory, source_description)

    result = version_parser.parse(unparsed_text)
    if result.nil?
      raise_parse_error(version_parser, unparsed_text, extended_description)
    end

    statement = result.get_grammar_version(
      Fig::ParserPackageBuildState.new(nil, descriptor, extended_description)
    )
    return 0 if not statement

    version = statement.version
    if version > 1
      raise Fig::PackageParseError.new(
        %Q<Don't know how to parse grammar version #{version}#{statement.position_string()}.>
      )
    end

    return version
  end

  def parse_v0(descriptor, directory, source_description, unparsed_text)
    stripped_text = unparsed_text.gsub(/#.*$/, '') # Blech.

    v0_parser = Fig::Grammar::V0Parser.new

    return drive_treetop_parser(
      v0_parser,
      descriptor,
      directory,
      source_description,
      unparsed_text,
      stripped_text
    )
  end

  def parse_v1(descriptor, directory, source_description, unparsed_text)
    v1_parser = Fig::Grammar::V1Parser.new

    return drive_treetop_parser(
      v1_parser,
      descriptor,
      directory,
      source_description,
      unparsed_text,
      unparsed_text
    )
  end

  def drive_treetop_parser(
    parser,
    descriptor,
    directory,
    source_description,
    unparsed_text, # Ugh. V0 strips comments via regex.
    cleaned_text
  )
    # Extra space at the end because most of the rules in the grammar require
    # trailing whitespace.
    result = parser.parse(cleaned_text + ' ')

    extended_description =
      extend_source_description(directory, source_description)

    if result.nil?
      raise_parse_error(parser, cleaned_text, extended_description)
    end

    package = result.to_package(
      directory,
      Fig::ParserPackageBuildState.new(
        parser.version, descriptor, extended_description
      )
    )
    package.unparsed_text = unparsed_text

    check_for_bad_urls(package, descriptor)
    check_for_multiple_command_statements(package)
    check_for_missing_versions_on_include_statements(package)

    return package
  end

  def extend_source_description(directory, original_description)
    if original_description
      extended = original_description
      if directory != '.'
        extended << " (#{directory})"
      end

      return extended
    end

    return directory
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
