require 'fig/command/action'
require 'fig/command/action/role/list_base_config'
require 'fig/command/action/role/list_variables_in_a_tree'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::Tree
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListBaseConfig
  include Fig::Command::Action::Role::ListVariablesInATree
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-variables --list-tree>
  end
end
