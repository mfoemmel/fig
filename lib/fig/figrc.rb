require 'json'

require 'fig/applicationconfiguration'
require 'fig/os'

REPOSITORY_CONFIGURATION = '_meta/figrc'

module Fig
  class FigRC
    def self.find(override_path, repository_url, login, fig_home)
      configuration = ApplicationConfiguration.new(repository_url)
      if not override_path.nil?
        configuration.push_dataset(JSON.parse(File::open(override_path).read))
      end

      user_figrc_path = File.expand_path('~/.figrc')
      if File.exists? user_figrc_path
        configuration.push_dataset(JSON.parse(File::open(user_figrc_path).read))
      end

      return configuration if repository_url.nil?

      figrc_url = "#{repository_url}/#{REPOSITORY_CONFIGURATION}"
      repo_figrc_path = File.expand_path(File.join(fig_home, REPOSITORY_CONFIGURATION))

      os = OS.new(login)

      exists = nil
      begin
        os.download( figrc_url, repo_figrc_path )
        exists = true
      rescue NotFoundError => e
        exists = false
      end

      return configuration if not exists

      configuration.push_dataset(JSON.parse(File.open(repo_figrc_path).read))

      return configuration
    end
  end
end
