require 'fig/logging'
require 'fig/packageerror'

module Fig; end
class Fig::Package; end

class Fig::Package::Override
  attr_reader :package_name, :version_name

  def initialize(package_name, version_name)
    @package_name = package_name
    @version_name = version_name
  end

  def unparse()
    return ' override ' + @package_name + '/' + @version_name
  end
end
