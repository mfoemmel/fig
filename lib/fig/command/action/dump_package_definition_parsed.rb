require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::DumpPackageDefinitionParsed
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--dump-package-definition-parsed>
  end

  def descriptor_requirement()
    return nil
  end

  def modifies_repository?()
    return false
  end

  def load_base_package?()
    return true
  end

  def register_base_package?()
    return false
  end

  def apply_config?()
    return false
  end

  def execute()
    lines = @execution_context.base_package.statements.map do
      |statement|

      statement.unparse('')
    end

    print lines.join("\n").strip

    return EXIT_SUCCESS
  end
end
