require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::RunCommandStatement
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--command-extra-args>
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
    @extra_argv = options.command_extra_argv
    @descriptor = options.descriptor

    return
  end

  def execute()
    environment   = @execution_context.environment
    base_package  = @execution_context.base_package
    base_config   = @execution_context.base_config

    environment.execute_config(
      base_package, base_config, @descriptor, @extra_argv || []
    ) { |command| @execution_context.operating_system.shell_exec command }

    # Will never get here.
  end
end
