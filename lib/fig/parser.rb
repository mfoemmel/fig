require 'polyglot'
require 'treetop'

require 'fig/grammar'
require 'fig/logging'
require 'fig/packageerror'
require 'fig/repository'
require 'fig/urlaccesserror'
require 'fig/userinputerror'

module Fig
  class Parser
    def initialize(application_config)
      @parser = FigParser.new
      @application_config = application_config
    end

    def find_bad_urls(package, package_name, version_name)
      bad_urls = []
      package.walk_statements do |statement|
        statement.urls.each do |url|
          # collect all bad urls in bad_urls
          next if not Repository.is_url?(url)
          bad_urls << url if not @application_config.url_access_allowed?(url)
        end
      end

      raise URLAccessError.new(bad_urls, package_name, version_name) if not bad_urls.empty?
    end

    def find_multiple_command_statements(package)
      command_processed = false
      package.walk_statements do |statement|
        if statement.is_a?(Package::Command)
          if command_processed == true
            raise UserInputError.new("Multiple command statements cannot be processed.")
          end
          command_processed = true
        elsif statement.is_a?(Package::Configuration)
          command_processed = false
        end
      end
    end

    def parse_package(package_name, version_name, directory, input)
      input = input.gsub(/#.*$/, '')
      result = @parser.parse(" #{input} ")

      if result.nil?
        Logging.fatal "#{directory}: #{@parser.failure_reason}"
        raise PackageError.new("#{directory}: #{@parser.failure_reason}")
      end

      package = result.to_package(package_name, version_name, directory)

      find_bad_urls(package, package_name, version_name)
      find_multiple_command_statements(package)

      return package
    end
  end
end
