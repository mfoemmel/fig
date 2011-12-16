require 'json'

require 'fig/applicationconfiguration'
require 'fig/configfileerror'
require 'fig/os'

REPOSITORY_CONFIGURATION = '_meta/figrc'

module Fig
  # Parse multiple figrc files and assemble them into a single
  # ApplicationConfiguration object.
  class FigRC
    def self.find(
      override_path, repository_url, login, fig_home, disable_figrc = false
    )
      configuration = ApplicationConfiguration.new(repository_url)

      handle_override_configuration(configuration, override_path)
      handle_figrc(configuration) if not disable_figrc
      handle_repository_configuration(
        configuration, repository_url, login, fig_home
      )

      return configuration
    end

    private

    def self.handle_override_configuration(configuration, override_path)
      begin
        if not override_path.nil?
          configuration.push_dataset(
            JSON.parse(File::open(override_path).read)
          )
        end
      rescue JSON::ParserError => exception
        translate_parse_error(exception, override_path)
      end

      return
    end

    def self.handle_figrc(configuration)
      user_figrc_path = File.expand_path('~/.figrc')
      return if not File.exists? user_figrc_path

      begin
        configuration.push_dataset(
          JSON.parse(File::open(user_figrc_path).read)
        )
      rescue JSON::ParserError => exception
        translate_parse_error(exception, user_figrc_path)
      end

      return
    end

    def self.handle_repository_configuration(
      configuration, repository_url, login, fig_home
    )
      return if repository_url.nil?

      figrc_url = "#{repository_url}/#{REPOSITORY_CONFIGURATION}"
      repo_figrc_path =
        File.expand_path(File.join(fig_home, REPOSITORY_CONFIGURATION))

      os = OS.new(login)

      repo_config_exists = nil
      begin
        os.download( figrc_url, repo_figrc_path )
        repo_config_exists = true
      rescue NotFoundError => e
        repo_config_exists = false
      end

      return configuration if not repo_config_exists

      begin
        configuration.push_dataset(
          JSON.parse(File.open(repo_figrc_path).read)
        )
      rescue JSON::ParserError => exception
        translate_parse_error(exception, figrc_url)
      end

      return
    end

    def self.translate_parse_error(json_parse_error, config_file_path)
      message = json_parse_error.message
      message.chomp!

      # JSON::ParserError tends to include final newline inside of single
      # quotes, which makes error messages ugly.
      message.sub!(/ \n+ ' \z /xm, %q<'>)

      # Also, there's a useless source code line number in the message.
      message.sub!(/ \A \d+ : \s+ /xm, %q<>)

      raise ConfigFileError.new(
        "Parse issue with #{config_file_path}: #{message}",
        config_file_path
      )
    end
  end
end
