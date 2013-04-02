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
    return nil # don't care
  end

  def apply_config?()
    return nil # don't care
  end

  def execute()
    if @execution_context.synthetic_package_for_command_line
      # Purposely syntactically incorrect so that nothing attempts to round
      # trip this.
      puts "---- synthetic package for command-line ----\n"
      dump_package @execution_context.synthetic_package_for_command_line

      puts "\n---- base package ----\n"
    end

    dump_package @execution_context.base_package

    return EXIT_SUCCESS
  end

  private

  def dump_package(package)
    text_assembler = Fig::PackageDefinitionTextAssembler.new :emit_as_input
    text_assembler.add_output package.statements

    unparsed, * = text_assembler.assemble_package_definition
    print unparsed

    return
  end
end
