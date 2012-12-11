require 'cgi'
require 'uri'

require 'fig/user_input_error'

module Fig; end

module Fig::URL
  # From https://www.rfc-editor.org/rfc/rfc1738.txt
  def self.is_url?(url)
    # We don't count single-letter "protocols" to allow for Windows drive
    # letters in paths.
    return !! ( url =~ %r< \A [a-z0-9+.-]{2,} : >ix )
  end

  # Encodes components and joins with slashes.
  def self.append_path_components(base_url, components)
    url     = base_url.sub(%r< / \z >x, '')
    encoded = components.map { |component| CGI.escape component }

    return [url, encoded].flatten.join('/')
  end

  # URI.parse() doesn't like space characters, unlike most of the world.
  def self.parse(url)
    begin
      return URI.parse(url.gsub ' ', '+')
    rescue URI::InvalidURIError => error
      raise Fig::UserInputError.new \
        %Q<Cannot parse URL "#{url}": #{error.message}>
    end
  end
end
