# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/list_all_configs'
require 'fig/command/action/role/list_as_json'
require 'fig/command/action/role/list_dependencies_from_data_structure'
require 'fig/command/action/role/list_from_data_structure'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::JSONAllConfigs
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAllConfigs
  include Fig::Command::Action::Role::ListAsJSON
  include Fig::Command::Action::Role::ListDependenciesFromDataStructure
  include Fig::Command::Action::Role::ListFromDataStructure
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-dependencies --json --list-all-configs>
  end

  def descriptor_requirement()
    return nil
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return nil # don't care
  end

  def apply_config?()
    return nil # don't care
  end

  def apply_base_config?()
    return nil # don't care
  end
end
