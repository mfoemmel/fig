require 'highline'
require 'net/netrc'

require 'fig/user_input_error'

module Fig; end
module Fig::Protocol; end

# Login information acquisition via .netrc.
module Fig::Protocol::NetRCEnabled
  private

  def get_username()
    @username ||= HighLine.new.ask('Username: ') { |q| q.echo = true }
    return @username
  end

  def get_password()
    @password ||= HighLine.new.ask('Password: ') { |q| q.echo = false }
    return @password
  end

  def load_authentication_for(host)
    return if @username || @password

    @username ||= ENV['FIG_USERNAME']
    @password ||= ENV['FIG_PASSWORD']
    return if @username || @password

    begin
      login_data = Net::Netrc.locate host
      if login_data
        @username = login_data.login
        @password = login_data.password
      end
    rescue SecurityError => error
      raise Fig::UserInputError.new error.message
    end

    return
  end
end
