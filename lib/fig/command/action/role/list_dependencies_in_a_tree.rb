# coding: utf-8

require 'fig/command/action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesInATree
  def execute()
    walk_dependency_tree(
      @execution_context.base_package, base_display_config_names()
    ) do
      |package, config_name, depth|

      print ' ' * (depth * 4)
      puts package.to_s_with_config(config_name)
    end

    return Fig::Command::Action::EXIT_SUCCESS
  end
end
