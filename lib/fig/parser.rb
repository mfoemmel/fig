require 'set'
require 'treetop'

require 'fig/grammar/v1' # this is grammar/v1.treetop, not grammar_v1.rb.
require 'fig/logging'
require 'fig/package_parse_error'
require 'fig/parser_package_build_state'
require 'fig/repository'
require 'fig/statement'
require 'fig/url_access_error'
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
    # Fig::V1Parser class is synthesized by Treetop.
    @treetop_parser         = Fig::V1Parser.new
    @application_config     = application_config
    @check_include_versions = check_include_versions
  end

  def parse_package(descriptor, directory, source_description, unparsed_text)
    # Bye bye comments.
    stripped_text = unparsed_text.gsub(/#.*$/, '')

    # Extra space at the end because most of the rules in the grammar require
    # trailing whitespace.
    result = @treetop_parser.parse(stripped_text + ' ')

    extended_description =
      extend_source_description(directory, source_description)

    if result.nil?
      raise_parse_error(extended_description)
    end

    package = result.to_package(
      directory,
      Fig::ParserPackageBuildState.new(descriptor, extended_description)
    )
    package.unparsed_text = unparsed_text

    check_for_bad_urls(package, descriptor)
    check_for_multiple_command_statements(package)
    check_for_missing_versions_on_include_statements(package)

    return package
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

  def raise_parse_error(extended_description)
    message = extended_description
    message << ": #{@treetop_parser.failure_reason}"

    raise Fig::PackageParseError.new(message)
  end

  def check_for_bad_urls(package, descriptor)
    return if not @application_config

    bad_urls = []
    package.walk_statements do |statement|
      statement.urls.each do |url|
        # collect all bad urls in bad_urls
        next if not Fig::Repository.is_url?(url)
        bad_urls << url if not @application_config.url_access_allowed?(url)
      end
    end

    raise Fig::URLAccessError.new(bad_urls, descriptor) if not bad_urls.empty?

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
