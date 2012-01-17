require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# Specifies a file (possibly via a URL) that is part of the current package.
#
# Differs from an Archive in that the contents will not be extracted.
class Fig::Package::Resource
  include Fig::Package::Statement

  attr_reader :url

  def initialize(url)
    @url = url
  end

  def urls
    return [@url]
  end

  def unparse(indent)
    "#{indent}resource #{url}"
  end
end
