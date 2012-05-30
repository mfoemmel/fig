require 'set'

require 'fig/command/action'
require 'fig/command/action/role/list_all_configs'
require 'fig/command/action/role/list_walking_dependency_tree'
require 'fig/statement/path'
require 'fig/statement/set'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end
class   Fig::Command::Action::ListVariables; end

class Fig::Command::Action::ListVariables::AllConfigs
  include Fig::Command::Action
  include Fig::Command::Action::Role::ListAllConfigs
  include Fig::Command::Action::Role::ListWalkingDependencyTree

  def options()
    return %w<--list-variables --list-all-configs>
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

  def execute()
    variable_names = Set.new()

    walk_dependency_tree(
      @execution_context.base_package, base_display_config_names(), nil, 0
    ) do
      |package, config_name, depth|

      package[config_name].walk_statements() do |statement|
        case statement
          when Fig::Statement::Path
            variable_names << statement.name()
          when Fig::Statement::Set
            variable_names << statement.name()
        end
      end
    end

    variable_names.sort.each { |name| puts name }

    return EXIT_SUCCESS
  end
end
