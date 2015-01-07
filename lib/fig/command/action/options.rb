# coding: utf-8

require 'fig/command/action'
require 'fig/command/action/role/has_no_sub_action'

module  Fig; end
class   Fig::Command; end
module  Fig::Command::Action; end

class Fig::Command::Action::Options
  include Fig::Command::Action
  include Fig::Command::Action::Role::HasNoSubAction

  def options()
    return %w<--options>
  end

  def execute_immediately_after_command_line_parse?
    return true
  end

  def configure(options)
    @options_message = options.options_message
  end

  def execute()
    puts "Fig options:\n\n"
    puts @options_message

    return EXIT_SUCCESS
  end
end
