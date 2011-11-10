require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Resource
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def unparse(indent)
    "#{indent}resource #{url}"
  end
end
