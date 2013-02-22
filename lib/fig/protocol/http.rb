require 'net/http'
require 'uri'

require 'fig/file_not_found_error'
require 'fig/logging'
require 'fig/network_error'
require 'fig/protocol'

module Fig; end
module Fig::Protocol; end

# File transfers via HTTP.
class Fig::Protocol::HTTP
  include Fig::Protocol

  # Returns whether the file was not downloaded because the file already
  # exists and is already up-to-date.
  def download(uri, path, prompt_for_login)
    log_download(uri, path)
    ::File.open(path, 'wb') do |file|
      file.binmode

      begin
        download_via_http_get(uri, file)
      rescue SystemCallError => error
        Fig::Logging.debug error.message
        raise Fig::FileNotFoundError.new error.message, uri
      rescue SocketError => error
        Fig::Logging.debug error.message
        raise Fig::FileNotFoundError.new error.message, uri
      end
    end
  end

  private

  def download_via_http_get(uri_string, file, redirection_limit = 10)
    if redirection_limit < 1
      Fig::Logging.debug 'Too many HTTP redirects.'
      raise Fig::FileNotFoundError.new 'Too many HTTP redirects.', uri_string
    end

    response = Net::HTTP.get_response(URI(uri_string))

    case response
    when Net::HTTPSuccess then
      file.write(response.body)
    when Net::HTTPRedirection then
      location = response['location']
      Fig::Logging.debug "Redirecting to #{location}."
      download_via_http_get(location, file, redirection_limit - 1)
    else
      Fig::Logging.debug "Download failed: #{response.code} #{response.message}."
      raise Fig::FileNotFoundError.new(
        "Download failed: #{response.code} #{response.message}.", uri_string
      )
    end

    return
  end
end
