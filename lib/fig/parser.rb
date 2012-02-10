require 'polyglot'
require 'treetop'

require 'fig/grammar'
require 'fig/logging'
require 'fig/packageparseerror'
require 'fig/repository'
require 'fig/urlaccesserror'
require 'fig/userinputerror'

module Fig
  # Parses configuration files and deals with a few restrictions on them.
  class Parser
    def self.node_location(node)
      offset_from_start_of_file = node.interval.first
      input = node.input

      return [
        input.line_of(offset_from_start_of_file),
        input.column_of(offset_from_start_of_file)
      ]
    end

    def initialize(application_config)
      @parser = FigParser.new
      @application_config = application_config
    end

    def find_bad_urls(package, descriptor)
      bad_urls = []
      package.walk_statements do |statement|
        statement.urls.each do |url|
          # collect all bad urls in bad_urls
          next if not Repository.is_url?(url)
          bad_urls << url if not @application_config.url_access_allowed?(url)
        end
      end

      raise URLAccessError.new(bad_urls, descriptor) if not bad_urls.empty?
    end

    def find_multiple_command_statements(package)
      command_processed = false
      package.walk_statements do |statement|
        if statement.is_a?(Statement::Command)
          if command_processed == true
            raise UserInputError.new(
              %Q<Found a second "command" statement within a "config" block#{statement.position_string()}.>
            )
          end
          command_processed = true
        elsif statement.is_a?(Statement::Configuration)
          command_processed = false
        end
      end
    end

    def parse_package(descriptor, directory, input)
      # Bye bye comments.
      input = input.gsub(/#.*$/, '')

      # Extra space at the end because most of the rules in the grammar require
      # trailing whitespace.
      result = @parser.parse(input + ' ')

      if result.nil?
        Logging.fatal "#{directory}: #{@parser.failure_reason}"
        raise PackageParseError.new("#{directory}: #{@parser.failure_reason}")
      end

      package = result.to_package(descriptor, directory)

      find_bad_urls(package, descriptor)
      find_multiple_command_statements(package)

      return package
    end
  end
end
