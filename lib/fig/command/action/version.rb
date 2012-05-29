require 'fig/command'
require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Version
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--version>
  end

  def execute_immediately_after_command_line_parse?
    return true
  end

  def execute()
    version = Fig::Command.get_version()
    return EXIT_FAILURE if version.nil?

    puts File.basename($0) + ' v' + version

    return EXIT_SUCCESS
  end
end
