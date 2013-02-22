require 'highline'
require 'net/netrc'

require 'fig/user_input_error'

module Fig; end
module Fig::Protocol; end

# Login information acquisition via .netrc.
module Fig::Protocol::NetRCEnabled
  private

  NetRCEntry = Struct.new :username, :password

  def initialize_netrc()
    @netrc_entries_by_host = {}

    return
  end

  def get_authentication_for(host, prompt_if_missing)
    if @netrc_entries_by_host.include? host
      return @netrc_entries_by_host[host]
    end

    entry = nil
    begin
      login_data = Net::Netrc.locate host
      if login_data
        entry = NetRCEntry.new login_data.login, login_data.password
      elsif prompt_if_missing
        entry = get_authentication_from_user(host)
      end
    rescue SecurityError => error
      raise Fig::UserInputError.new error.message
    end

    @netrc_entries_by_host[host] = entry

    return entry
  end

  def get_authentication_from_user(host)
    username =
      ENV['FIG_USERNAME'] ||
      HighLine.new.ask("Username for #{host}: ") { |q| q.echo = true }
    password =
      ENV['FIG_PASSWORD'] ||
      HighLine.new.ask("Password for #{username}@#{host}: ") {
        |q| q.echo = false
      }

    return NetRCEntry.new username, password
  end
end
