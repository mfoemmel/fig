require 'fig/logging'
require 'fig/packageerror'
require 'fig/package/statement'

module Fig; end
class Fig::Package; end

# Dual role: "include :configname" incorporates one configuration into another;
# "include package[/version]" declares a dependency upon another package.
class Fig::Package::Include
  include Fig::Package::Statement

  attr_reader :package_name, :config_name, :version_name, :overrides

  def initialize(descriptor, overrides)
    @package_name = descriptor.name
    @config_name = descriptor.config
    @version_name = descriptor.version
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
