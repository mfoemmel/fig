require 'cgi'

module Fig; end

module Fig::URL
  def self.is_url?(url)
    return url =~ %r<\A (?: ftp: | https?: | file: | ssh: ) //>x
  end

  # Encodes components and joins with slashes.
  def self.append_path_components(base_url, components)
    url     = base_url.sub(%r< / \z >x, '')
    encoded = components.map { |component| CGI.escape component }

    return [url, encoded].flatten.join('/')
  end
end
