require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

class Fig::Package::Include
  include Fig::Package::Statement

  attr_reader :package_name, :config_name, :version_name, :overrides

  def initialize(package_name, config_name, version_name, overrides)
    @package_name = package_name
    @config_name = config_name
    @version_name = version_name
    @overrides = overrides
  end

  def unparse(indent)
    descriptor = ''
    descriptor += @package_name if @package_name
    descriptor += "/#{@version_name}" if @version_name
    descriptor += ":#{@config_name}" if @config_name
    @overrides.each do |override|
      descriptor += override.unparse
    end
    return "#{indent}include #{descriptor}"
  end
end
