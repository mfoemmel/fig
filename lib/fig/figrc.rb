require 'json'

require 'fig/applicationconfiguration'
require 'fig/os'

REPOSITORY_CONFIGURATION = '_meta/figrc'

module Fig
  class FigRC
    def self.find(override_path, repository_url, login, home)
      configuration = ApplicationConfiguration.new()
      if not override_path.nil?
        configuration.push_dataset(JSON.parse(File::open(override_path).read))
      end

      return configuration if repository_url.nil?

      figrc_url = "#{repository_url}/#{REPOSITORY_CONFIGURATION}"
      figrc_path = File.expand_path(File.join(home, REPOSITORY_CONFIGURATION))

      os = OS.new(login)

      exists = nil
      begin
        os.download( figrc_url, figrc_path )
        exists = true
      rescue NotFoundException => e
        exists = false
      end

      return configuration if not exists

      configuration.push_dataset(JSON.parse(File.open(figrc_path).read))

      return configuration

    end

    def self.load_from_handle(handle)
      configuration = ApplicationConfiguration.new()
      configuration.push_dataset(JSON.parse(handle.read))
      return configuration
    end
  end
end

