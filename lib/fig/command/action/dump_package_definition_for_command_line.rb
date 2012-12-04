require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'
require 'fig/package_definition_text_assembler'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::DumpPackageDefinitionForCommandLine
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--dump-package-definition-for-command-line>
  end

  def descriptor_requirement()
    return nil
  end

  def cares_about_asset_options?()
    return true
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

  def configure(options)
    @environment_statements = options.environment_statements
    @asset_statements       = options.asset_statements

    return
  end

  def execute()
    text_assembler = Fig::PackageDefinitionTextAssembler.new :emit_as_input
    text_assembler.add_output @asset_statements
    text_assembler.add_output [
      Fig::Statement::Configuration.new(
        nil,
        nil,
        Fig::Package::DEFAULT_CONFIG,
        @environment_statements
      )
    ]


    unparsed, explanations = text_assembler.assemble_package_definition
    print unparsed

    return EXIT_SUCCESS
  end
end
