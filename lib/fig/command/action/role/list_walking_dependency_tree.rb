require 'set'

require 'fig/include_backtrace'
require 'fig/package_descriptor'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListWalkingDependencyTree
  def walk_dependency_tree(base_package, config_names, backtrace, depth, &block)
    config_names.each do
      |config_name|

      if depth < 1
        @execution_context.repository.reset_cached_data
      end

      yield base_package, config_name, depth

      new_backtrace = Fig::IncludeBacktrace.new(
        backtrace,
        Fig::PackageDescriptor.new(
          base_package.name(),
          base_package.version(),
          config_name
        )
      )

      base_package.package_dependencies(config_name, new_backtrace).each do
        |descriptor|

        package = nil
        if descriptor.name
          package =
            @execution_context.repository.get_package(
              descriptor, :allow_any_version
            )
        else
          package = base_package
        end

        walk_dependency_tree(
          package, [descriptor.config], new_backtrace, depth + 1, &block
        )
      end
    end

    return
  end

  def configure(options)
    @descriptor = options.descriptor
  end

  def gather_package_dependency_configurations()
    packages = {}
    starting_config_names = base_display_config_names()
    base_package = @execution_context.base_package

    if ! base_package.name.nil?
      packages[base_package] = starting_config_names.to_set
    end

    walk_dependency_tree(base_package, starting_config_names, nil, 0) do
      |package, config_name, depth|

      if (
            ! package.name.nil?           \
        &&  ! (
                  ! list_all_configs?    \
              &&  @descriptor                     \
              &&  package.name == @descriptor.name
            )
      )
        packages[package] ||= Set.new
        packages[package] << config_name
      end
    end

    if ! list_all_configs? && @descriptor
      packages.reject! do |package, config_names|
        package.name == @descriptor.name
      end
    end

    return packages
  end
end
