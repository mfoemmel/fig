require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/unparser/v0'

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
    unparser = Fig::Unparser::V0.new :emit_as_input
    text = unparser.unparse(@execution_context.base_package.statements)

    print text.gsub(/\n{3,}/, "\n\n").strip

    return EXIT_SUCCESS
  end
end
