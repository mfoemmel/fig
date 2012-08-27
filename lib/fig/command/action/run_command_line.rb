require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::RunCommandLine
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<-->
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
    return true
  end

  def apply_config?()
    return true
  end

  def apply_base_config?()
    return true
  end

  def configure(options)
    @command_line = options.shell_command

    return
  end

  def execute()
    @execution_context.environment.execute_shell(@command_line) do
      |command| @execution_context.operating_system.plain_or_shell_exec command
    end

    return EXIT_SUCCESS
  end
end
