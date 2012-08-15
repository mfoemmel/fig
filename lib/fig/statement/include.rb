require 'fig/package_descriptor'
require 'fig/statement'

module Fig; end

# Dual role: "include :configname" incorporates one configuration into another;
# "include package[/version]" declares a dependency upon another package (with
# incorporation of the "default" configuration from that other package if no
# ":configname" is specified.
class Fig::Statement::Include < Fig::Statement
  attr_reader :descriptor, :containing_package_descriptor

  # Centralized definition of requirements for descriptors for include
  # statements.
  def self.parse_descriptor(raw_string, options = {})
    return Fig::PackageDescriptor.parse(raw_string, options)
  end

  def initialize(line_column, source_description, descriptor, containing_package_descriptor)
    super(line_column, source_description)

    @descriptor                    = descriptor
    @containing_package_descriptor = containing_package_descriptor
  end

  def package_name
    return @descriptor.name
  end

  def version
    return @descriptor.version
  end

  def config_name
    return @descriptor.config
  end

  def complain_if_version_missing()
    if @descriptor.name && ! @descriptor.version
      message =
        %Q<No version in the package descriptor of "#{@descriptor.name}" in an include statement>
      if @containing_package_descriptor
        package_string = @containing_package_descriptor.to_string()
        if package_string && package_string != ''
          message += %Q< in the .fig file for "#{package_string}">
        end
      end
      message += %Q<#{position_string()}. Whether or not the include statement will work is dependent upon the recursive dependency load order.>

      Fig::Logging.warn(message)
    end
  end

  # Assume that this statement is part of the parameter and return a descriptor
  # that represents the fully resolved dependency, taking into account that the
  # version might have been overridden.
  def resolved_dependency_descriptor(containing_package, backtrace)
    return Fig::PackageDescriptor.new(
      referenced_package_name(containing_package),
      referenced_version(containing_package, backtrace),
      referenced_config_name()
    )
  end

  def unparse_as_version(unparser)
    return unparser.include(self)
  end

  def minimum_grammar_for_publishing()
    return [0]
  end

  private

  def referenced_package_name(containing_package)
    return package_name() || containing_package.name()
  end

  def referenced_version(containing_package, backtrace)
    package_name = nil
    original_version = nil
    if package_name()
      package_name = package_name()
      original_version = version()
    else
      package_name = containing_package.name()
      original_version = containing_package.version()
    end

    return backtrace.get_override(package_name, original_version)
  end

  def referenced_config_name()
    config_name() || Fig::Package::DEFAULT_CONFIG
  end
end
