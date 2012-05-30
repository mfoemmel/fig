require 'fig/command/action'
require 'fig/command/action/role/list_all_configs'
require 'fig/command/action/role/list_dependencies_flat'
require 'fig/command/action/role/list_walking_dependency_tree'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListDependencies; end

class Fig::Command::Action::ListDependencies::AllConfigs
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAllConfigs
  include Fig::Command::Action::Role::ListDependenciesFlat
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-dependencies --list-all-configs>
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

  def apply_config?
    return nil # don't care
  end

  def derive_package_strings(packages)
    return packages.keys.collect do
      |package|

      packages[package].collect {|config| package.to_s_with_config(config)}
    end.flatten
  end
end
