require 'json'

require 'fig/applicationconfiguration'
require 'fig/os'

REPOSITORY_CONFIGURATION = '_meta/figrc'

module Fig
  class FigRC
    def self.find(override_path, repository_url, login, home)
      if not override_path.nil?
        return ApplicationConfiguration.new(
          JSON.parse(File::open(override_path).read)
        )
      end
      return ApplicationConfiguration.new({}) if repository_url.nil?

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

      return ApplicationConfiguration.new({}) if not exists
      return ApplicationConfiguration.new(JSON.parse(File.open(figrc_path).read))
    end

    def self.load_from_handle(handle)
      ApplicationConfiguration.new(
        JSON.parse(handle.read)
      )
    end
  end
end

