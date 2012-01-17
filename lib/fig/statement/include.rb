require 'fig/logging'
require 'fig/packageerror'
require 'fig/statement'

module Fig; end

# Dual role: "include :configname" incorporates one configuration into another;
# "include package[/version]" declares a dependency upon another package.
class Fig::Statement::Include
  include Fig::Statement

  attr_reader :descriptor, :overrides

  def initialize(descriptor, overrides)
    @descriptor = descriptor
    @overrides = overrides
  end

  def package_name
    return @descriptor.name
  end

  def config_name
    return @descriptor.config
  end

  def version_name
    return @descriptor.version
  end

  def unparse(indent)
    text = ''
    text += package_name() if package_name()
    text += "/#{version_name()}" if version_name()
    text += ":#{config_name()}" if config_name()
    @overrides.each do |override|
      text += override.unparse
    end
    return "#{indent}include #{text}"
  end
end
