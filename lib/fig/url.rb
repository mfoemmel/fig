require 'cgi'
require 'uri'

module Fig; end

module Fig::URL
  # From https://www.rfc-editor.org/rfc/rfc1738.txt
  def self.is_url?(url)
    return !! ( url =~ %r< \A [a-z0-9+.-]+ : >ix )
  end

  # Encodes components and joins with slashes.
  def self.append_path_components(base_url, components)
    url     = base_url.sub(%r< / \z >x, '')
    encoded = components.map { |component| CGI.escape component }

    return [url, encoded].flatten.join('/')
  end

  # URI.parse() doesn't like space characters, unlike most of the world.
  def self.parse(url)
    return URI.parse(url.gsub ' ', '+')
  end
end
