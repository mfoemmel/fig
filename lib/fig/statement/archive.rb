require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# Specifies an archive file (possibly via a URL) that is part of the current package.
#
# Differs from a Resource in that the contents will be extracted.
class Fig::Package::Archive
  include Fig::Package::Statement

  attr_reader :url

  def initialize(url)
    @url = url
  end

  def urls
    return [@url]
  end

  def unparse(indent)
    %Q<#{indent}archive "#{url}">
  end
end
