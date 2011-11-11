require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

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
