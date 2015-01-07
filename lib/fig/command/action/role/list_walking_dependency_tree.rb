# coding: utf-8

require 'set'

require 'fig/include_backtrace'
require 'fig/package_descriptor'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListWalkingDependencyTree
  def modifies_repository?()
    return false
  end

  def walk_dependency_tree(
    base_package, config_names, include_block = nil, &package_block
  )
    do_walk_dependency_tree(
      base_package, config_names, nil, 0, include_block, &package_block
    )

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

    do_walk_dependency_tree(base_package, starting_config_names, nil, 0, nil) do
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

  private

  def do_walk_dependency_tree(
    base_package, config_names, backtrace, depth, include_block, &package_block
  )
    config_names.each do
      |config_name|

      if depth < 1
        @execution_context.repository.reset_cached_data
      end

      package_block.call base_package, config_name, depth

      new_backtrace = new_backtrace(backtrace, base_package, config_name)

      base_package.package_dependencies(config_name, new_backtrace).each do
        |descriptor|

        package = package_for_descriptor descriptor, base_package

        do_walk_dependency_tree(
          package,
          [descriptor.config],
          new_backtrace,
          depth + 1,
          include_block,
          &package_block
        )

        if include_block
          include_block.call(
            base_package, config_name, package, descriptor.config
          )
        end
      end
    end

    return
  end

  def new_backtrace(backtrace, base_package, config_name)
    return Fig::IncludeBacktrace.new(
      backtrace,
      Fig::PackageDescriptor.new(
        base_package.name(),
        base_package.version(),
        config_name,
        :description => base_package.description
      )
    )
  end

  def package_for_descriptor(descriptor, base_package)
    if descriptor.name
      return @execution_context.repository.get_package(
        descriptor, :allow_any_version
      )
    end

    return base_package
  end
end
