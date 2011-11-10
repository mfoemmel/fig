require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Archive
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def unparse(indent)
    %Q<#{indent}archive "#{url}">
  end
end
