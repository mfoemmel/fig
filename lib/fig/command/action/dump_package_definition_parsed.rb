require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/package_definition_text_assembler'

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
    text_assembler = Fig::PackageDefinitionTextAssembler.new :emit_as_input
    text_assembler.add_output @execution_context.base_package.statements

    print text_assembler.assemble_package_definition

    return EXIT_SUCCESS
  end
end
