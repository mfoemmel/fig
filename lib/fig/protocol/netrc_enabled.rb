# coding: utf-8

require 'highline'
require 'net/netrc'

require 'fig/logging'
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
    if prompt_if_missing
      entry = get_authentication_from_environment
    end

    if ! entry
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
    end

    @netrc_entries_by_host[host] = entry

    return entry
  end

  def get_authentication_from_environment()
    username = ENV['FIG_USERNAME']
    password = ENV['FIG_PASSWORD']

    if username.nil? && password.nil?
      return nil
    end

    if ! username.nil? && ! password.nil?
      return NetRCEntry.new username, password
    end

    if password.nil?
      raise Fig::UserInputError.new \
        'FIG_USERNAME is set but FIG_PASSWORD is not.'
    end

    raise Fig::UserInputError.new 'FIG_PASSWORD is set but FIG_USERNAME is not.'
  end

  def get_authentication_from_user(host)
    # This defaults to true, but Net::SSH::Prompt turns it off.  Unfortunately,
    # this causes HighLine to barf when there's no input on STDIN, e.g. when
    # running on a continuous integration server.
    HighLine.track_eof = true

    begin
      username =
        HighLine.new.ask("Username for #{host}: ") { |q| q.echo = true }
      password = HighLine.new.ask("Password for #{username}@#{host}: ") {
        |q| q.echo = false
      }

      return NetRCEntry.new username, password
    rescue EOFError => error
      Fig::Logging.debug(error)

      return nil
    end
  end
end
