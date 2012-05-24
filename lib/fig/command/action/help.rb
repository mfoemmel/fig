require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Help
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options
    return %w<--help>
  end

  def descriptor_requirement()
    return :ignore
  end

  def allow_both_descriptor_and_file?
    # Help has to basically allow anything.
    return true
  end

  def need_base_package?()
    return false
  end

  def need_base_config?()
    return false
  end

  def register_base_package?()
    return false
  end

  def apply_base_config?()
    return false
  end

  def configure(options)
    @help_message = options.help_message
  end

  def execute(repository)
    puts @help_message

    return 0
  end
end
