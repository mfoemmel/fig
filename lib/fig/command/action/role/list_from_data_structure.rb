# coding: utf-8

require 'set'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

# Requires #node_content(package, config_name) and #walk_dependency_tree()
# methods.
module Fig::Command::Action::Role::ListFromDataStructure
  private

  def set_up_object_to_be_serialized
    @package_configs = {}

    base_package = @execution_context.base_package
    base_configs = base_display_config_names
    walk_dependency_tree(
      base_package, base_configs, include_gather, &package_gather
    )

    base_id = package_id base_package
    if base_configs.size > 1
      @object_to_be_serialized = @package_configs[base_id].keys.collect do
        |config_name|

        @package_configs[base_id][config_name]
      end
    else
      @object_to_be_serialized = @package_configs[base_id][base_configs[0]]
    end
  end

  def include_gather
    visited = Set.new

    return lambda do
      |including_package, including_config, included_package, included_config|

      including_name = including_package.to_s_with_config including_config
      included_name = included_package.to_s_with_config included_config
      edge = [including_name, included_name]

      if ! visited.include? edge
        visited << edge

        included_id    = package_id included_package
        including_id   = package_id including_package
        including_hash = @package_configs[including_id][including_config]

        including_hash['dependencies'] ||= []
        including_hash['dependencies'] <<
          @package_configs[included_id][included_config]
      end
    end
  end

  def package_gather
    visited = Set.new

    return lambda do
      |package, config_name, depth|

      name = package.to_s_with_config config_name

      if ! visited.include? name
        visited << name

        id = package_id package
        @package_configs[id] ||= {}
        @package_configs[id][config_name] = node_content package, config_name
      end
    end
  end

  def new_package_config_hash(package, config_name)
    hash = {}

    if package.name
      hash['name'] = package.name
    end
    if package.version
      hash['version'] = package.version
    end
    if package.description
      hash['description'] = package.description
    end
    hash['config'] = config_name

    return hash
  end

  def package_id(package)
    return package.name || "description: #{package.description}"
  end
end
