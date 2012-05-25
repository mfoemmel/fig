module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
module  Fig::Command::Action::Role; end

module Fig::Command::Action::Role::ListDependenciesInATree
  # TODO: Delete this.
  def implemented?
    return true
  end

  def execute()
    walk_dependency_tree(
      @execution_context.base_package, base_display_config_names(), nil, 0
    ) do
      |package, config_name, depth|

      print ' ' * (depth * 4)
      puts package.to_s_with_config(config_name)
    end

    return 0
  end
end
