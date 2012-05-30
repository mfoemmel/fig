require 'fig/command/action'
require 'fig/command/action/role/list_base_config'
require 'fig/command/action/role/list_dependencies_in_a_tree'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::Tree
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListBaseConfig
  include Fig::Command::Action::Role::ListDependenciesInATree
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-dependencies --list-tree>
  end

  def descriptor_requirement()
    return nil
  end

  def need_base_package?()
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
