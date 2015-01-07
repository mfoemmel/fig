# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::HelpLong
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--help-long>
  end

  def execute_immediately_after_command_line_parse?
    return true
  end

  def configure(options)
    @help_message = options.full_help_message
  end

  def execute()
    puts @help_message

    return EXIT_SUCCESS
  end
end
