require 'fig/logging'
require 'fig/packagedescriptor'
require 'fig/statement'

module Fig; end

# Dual role: "include :configname" incorporates one configuration into another;
# "include package[/version]" declares a dependency upon another package.
class Fig::Statement::Include
  include Fig::Statement

  attr_reader :descriptor, :overrides

  def initialize(descriptor, overrides, containing_package_name)
    if descriptor.name && ! descriptor.version
      message =
        %Q<No version in the package descriptor of "#{descriptor.name}" in an include statement>
      if containing_package_name
        message += %Q< in the .fig file for "#{containing_package_name}">
      end
      message += '. Whether or not the include statement will work is dependent upon the recursive dependency load order.'

      Fig::Logging.warn(message)
    end

    @descriptor = descriptor
    @overrides = overrides
  end

  def package_name
    return @descriptor.name
  end

  def version_name
    return @descriptor.version
  end

  def config_name
    return @descriptor.config
  end

  # Assume that this statement is part of the parameter and return a descriptor
  # that represents the fully resolved dependency.
  def resolved_dependency_descriptor(package)
    return Fig::PackageDescriptor.new(
      referenced_package_name(package),
      referenced_version_name(package),
      referenced_config_name()
    )
  end

  # Block will receive a Package and a Statement.
  def walk_statements_following_package_dependencies(
    repository, package, &block
  )
    referenced_package = nil
    if package_name()
      referenced_package = repository.get_package(package_name, version_name)
    else
      referenced_package = package
    end

    configuration = referenced_package[referenced_config_name()]

    yield referenced_package, configuration
    configuration.walk_statements_following_package_dependencies(
      repository, referenced_package, &block
    )

    return
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

  private

  def referenced_package_name(package)
    return package_name() || package.package_name()
  end

  def referenced_version_name(package)
    if package_name()
      return version_name()
    end

    return version_name() || package.version_name()
  end

  def referenced_config_name()
    config_name() || Fig::Package::DEFAULT_CONFIG
  end
end
