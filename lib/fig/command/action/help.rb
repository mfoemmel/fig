require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Help
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--help>
  end

  def execute_immediately_after_command_line_parse?
    return true
  end

  def configure(options)
    @help_message = options.help_message
  end

  def execute()
    puts @help_message

    return EXIT_SUCCESS
  end
end
