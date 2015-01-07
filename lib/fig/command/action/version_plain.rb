# coding: utf-8

require 'fig'
require 'fig/command'
require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::VersionPlain
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--version-plain>
  end

  def execute_immediately_after_command_line_parse?
    return true
  end

  def configure(options)
    @version_plain = options.version_plain
  end

  def execute()
    print @version_plain || Fig::VERSION

    return EXIT_SUCCESS
  end
end
