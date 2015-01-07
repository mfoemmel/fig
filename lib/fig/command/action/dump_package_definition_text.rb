# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::DumpPackageDefinitionText
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--dump-package-definition-text>
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
    text = @execution_context.base_package.unparsed_text
    if text
      puts text.strip # Ensure one and only one ending newline.

      return EXIT_SUCCESS
    end

    $stderr.puts %q<There's no text for the package.>

    return EXIT_FAILURE
  end
end
