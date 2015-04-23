# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/list_all_configs'
require 'fig/command/action/role/list_as_yaml'
require 'fig/command/action/role/list_from_data_structure'
require 'fig/command/action/role/list_variables_from_data_structure'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::YAMLAllConfigs
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAllConfigs
  include Fig::Command::Action::Role::ListAsYAML
  include Fig::Command::Action::Role::ListFromDataStructure
  include Fig::Command::Action::Role::ListVariablesFromDataStructure
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-variables --list-yaml --list-all-configs>
  end
end
