# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/list_as_yaml'
require 'fig/command/action/role/list_base_config'
require 'fig/command/action/role/list_dependencies_from_data_structure'
require 'fig/command/action/role/list_from_data_structure'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::YAML
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAsYAML
  include Fig::Command::Action::Role::ListBaseConfig
  include Fig::Command::Action::Role::ListDependenciesFromDataStructure
  include Fig::Command::Action::Role::ListFromDataStructure
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-dependencies --yaml>
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
